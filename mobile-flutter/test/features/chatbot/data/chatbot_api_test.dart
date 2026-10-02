import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/api/api_client.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/features/chatbot/data/chatbot_api.dart';
import 'package:mobile_flutter/features/chatbot/domain/chatbot_models.dart';

import '../../../support/json_fixtures.dart';

const _base = 'http://api.test/api/v1';

class _Recorder {
  final requests = <http.Request>[];
  Object? reply;
  int status = 200;

  HttpChatbotRepository repository() => HttpChatbotRepository(
    ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(utf8.encode(jsonEncode(reply)), status);
      }),
      baseUrl: _base,
    ),
  );

  http.Request get last => requests.single;
}

void main() {
  late _Recorder api;

  setUp(() => api = _Recorder());

  test('start posts without a body and reads the greeting', () async {
    api
      ..status = 201
      ..reply = chatbotTurnJson();

    final turn = await api.repository().start();

    expect(api.last.method, 'POST');
    expect(api.last.url.toString(), '$_base/chatbot/conversations');
    expect(api.last.body, isEmpty);
    expect(turn.conversationId, 42);
    expect(turn.state, ChatbotState.inicio);
    expect(turn.messages.single.body, startsWith('Olá, Ana!'));
    expect(turn.options.map((o) => o.id), ['segment:DEFEITO_APP', 'human']);
  });

  test('send posts the typed text as JSON', () async {
    api.reply = chatbotTurnJson(state: 'CONFIRMACAO');

    await api.repository().send(42, const ChatbotReply.text('Não entro'));

    expect(api.last.method, 'POST');
    expect(api.last.url.toString(), '$_base/chatbot/conversations/42/messages');
    expect(api.last.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(api.last.body), {'text': 'Não entro'});
  });

  test('send posts the option id and reads the handoff', () async {
    api.reply = chatbotTurnJson(
      state: 'ENCAMINHAMENTO',
      options: const [],
      handoff: {'segment': 'DEFEITO_APP', 'description': ''},
    );

    final turn = await api.repository().send(
      42,
      const ChatbotReply.option('human'),
    );

    expect(jsonDecode(api.last.body), {'optionId': 'human'});
    expect(turn.state, ChatbotState.encaminhamento);
    expect(turn.handoff!.segment, 'DEFEITO_APP');
  });

  test('an error status becomes an ApiException', () async {
    api
      ..status = 409
      ..reply = {'message': 'Conversa encerrada.'};

    await expectLater(
      api.repository().send(42, const ChatbotReply.text('Oi')),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.conflict,
        ),
      ),
    );
  });

  test('a malformed body becomes a server error', () async {
    api.reply = chatbotTurnJson(state: 'PERDIDA');

    await expectLater(
      api.repository().start(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.server),
      ),
    );
  });
}
