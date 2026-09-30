import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/api/api_client.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

const _base = 'http://api.test/api/v1';

ApiClient _client(
  MockClientHandler handler, {
  Duration jsonTimeout = const Duration(seconds: 15),
}) => ApiClient(
  client: MockClient(handler),
  baseUrl: _base,
  jsonTimeout: jsonTimeout,
);

http.Response _json(Object body, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('GET joins the base URL, the path and the query', () async {
    late http.Request seen;
    final api = _client((request) async {
      seen = request;
      return _json([1, 2], 200);
    });

    final body = await api.getJson(
      '/notifications',
      query: {'unreadOnly': 'true'},
    );

    expect(seen.method, 'GET');
    expect(seen.url.toString(), '$_base/notifications?unreadOnly=true');
    expect(body, [1, 2]);
  });

  test('decodes UTF-8 bodies without a charset', () async {
    final api = _client((_) async => _json({'body': 'Olá, você'}, 200));

    final body = await api.getJson('/x') as Map<String, dynamic>;

    expect(body['body'], 'Olá, você');
  });

  test('POST without a body sends no content type', () async {
    late http.Request seen;
    final api = _client((request) async {
      seen = request;
      return _json({'ok': true}, 200);
    });

    await api.postJson('/tickets/7/confirm');

    expect(seen.method, 'POST');
    expect(seen.body, isEmpty);
    expect(seen.headers.containsKey('content-type'), isFalse);
  });

  test('POST with a body sends JSON', () async {
    late http.Request seen;
    final api = _client((request) async {
      seen = request;
      return http.Response('', 204);
    });

    final result = await api.postJson('/x', body: {'a': 1});

    expect(seen.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(seen.body), {'a': 1});
    expect(result, isNull);
  });

  test(
    'multipart sends the fields and each file with its content type',
    () async {
      late http.Request seen;
      final api = _client((request) async {
        seen = request;
        return _json({'id': 9}, 201);
      });

      final result = await api.postMultipart(
        '/tickets',
        fields: {'segment': 'DEFEITO_APP', 'description': 'Não abre'},
        files: [
          PickedAttachment(name: 'tela.png', bytes: Uint8List.fromList([1, 2])),
          PickedAttachment(name: 'nota.pdf', bytes: Uint8List.fromList([3])),
        ],
      );

      final body = utf8.decode(seen.bodyBytes);
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      expect(body, contains('name="segment"'));
      expect(body, contains('DEFEITO_APP'));
      expect(body, contains('Não abre'));
      expect(body, contains('name="files"; filename="tela.png"'));
      expect(body, contains('content-type: image/png'));
      expect(body, contains('name="files"; filename="nota.pdf"'));
      expect(body, contains('content-type: application/pdf'));
      expect(result, {'id': 9});
    },
  );

  test('getBytes returns the raw body', () async {
    final api = _client((_) async => http.Response.bytes([7, 8, 9], 200));

    expect(await api.getBytes('/tickets/7/attachments/3'), [7, 8, 9]);
  });

  test('maps the status codes and keeps the server message', () async {
    const cases = {
      400: ApiErrorKind.badRequest,
      401: ApiErrorKind.unauthorized,
      403: ApiErrorKind.forbidden,
      404: ApiErrorKind.notFound,
      409: ApiErrorKind.conflict,
      422: ApiErrorKind.unprocessable,
      500: ApiErrorKind.server,
      503: ApiErrorKind.server,
      302: ApiErrorKind.server,
    };
    for (final entry in cases.entries) {
      final api = _client(
        (_) async => _json({'message': 'Motivo ${entry.key}'}, entry.key),
      );
      await expectLater(
        api.getJson('/x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', entry.value)
              .having((e) => e.status, 'status', entry.key)
              .having(
                (e) => e.serverMessage,
                'serverMessage',
                'Motivo ${entry.key}',
              ),
        ),
        reason: '${entry.key}',
      );
    }
  });

  test('an error body that is not JSON has no server message', () async {
    final api = _client((_) async => http.Response('<html>', 502));

    await expectLater(
      api.getJson('/x'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.serverMessage,
          'serverMessage',
          isNull,
        ),
      ),
    );
  });

  test('a failed connection is a network error', () async {
    final api = _client((_) async => throw http.ClientException('recusada'));

    await expectLater(
      api.getJson('/x'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network),
      ),
    );
  });

  test('a timeout is a network error', () async {
    final api = _client(
      (_) => Completer<http.Response>().future,
      jsonTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      api.getJson('/x'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network),
      ),
    );
  });

  test('a 200 with a body that is not JSON is a server error', () async {
    final api = _client((_) async => http.Response('<html>', 200));

    await expectLater(
      api.getJson('/x'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.server),
      ),
    );
  });

  test(
    'decodeList and decodeObject turn a wrong shape into a server error',
    () async {
      await expectLater(
        () => decodeList({}, SegmentOption.fromJson),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
      await expectLater(
        () => decodeObject([1], TicketDetail.fromJson),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
      await expectLater(
        () => decodeObject({'id': 'x'}, SegmentOption.fromJson),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
    },
  );

  group('ApiException.message', () {
    test('fixed texts', () {
      expect(
        const ApiException(ApiErrorKind.network).message,
        'Sem conexão com o servidor.',
      );
      expect(
        const ApiException(ApiErrorKind.unauthorized).message,
        'Sua sessão expirou. Entre de novo.',
      );
      expect(
        const ApiException(ApiErrorKind.forbidden).message,
        'Esta conta não tem acesso a esta área.',
      );
      expect(
        const ApiException(ApiErrorKind.notFound).message,
        'Ticket não encontrado.',
      );
      expect(
        const ApiException(ApiErrorKind.conflict).message,
        'O ticket mudou de situação. A tela foi atualizada.',
      );
      expect(
        const ApiException(ApiErrorKind.server, serverMessage: 'x').message,
        'Erro no servidor. Tente de novo em instantes.',
      );
    });

    test('validation errors show the server message, with a fallback', () {
      expect(
        const ApiException(
          ApiErrorKind.badRequest,
          serverMessage: 'Anexo grande demais.',
        ).message,
        'Anexo grande demais.',
      );
      expect(
        const ApiException(ApiErrorKind.unprocessable).message,
        'Confira os dados e tente de novo.',
      );
    });
  });
}
