import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/api/api_client.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/tickets/data/ticket_api.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

import '../../../support/json_fixtures.dart';

const _base = 'http://api.test/api/v1';

class _Recorder {
  final requests = <http.Request>[];
  Object? reply;
  int status = 200;

  HttpTicketRepository repository() => HttpTicketRepository(
    ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        final body = reply;
        if (body is List<int>) return http.Response.bytes(body, status);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
      }),
      baseUrl: _base,
    ),
  );

  http.Request get last => requests.single;
}

void main() {
  late _Recorder api;

  setUp(() => api = _Recorder());

  test('segments', () async {
    api.reply = [segmentJson(), segmentJson(segment: 'PROBLEMA_PEDIDO')];

    final segments = await api.repository().segments();

    expect(api.last.method, 'GET');
    expect(api.last.url.toString(), '$_base/segments');
    expect(segments.map((s) => s.segment), ['DEFEITO_APP', 'PROBLEMA_PEDIDO']);
  });

  test('mine', () async {
    api.reply = [summaryJson(id: 9), summaryJson(id: 8)];

    final tickets = await api.repository().mine();

    expect(api.last.url.toString(), '$_base/tickets/mine');
    expect(tickets.map((t) => t.id), [9, 8]);
  });

  test('detail and messages', () async {
    api.reply = detailJson(id: 7);
    final detail = await api.repository().detail(7);
    expect(api.last.url.toString(), '$_base/tickets/7');
    expect(detail.id, 7);

    api = _Recorder()..reply = [messageJson(id: 1), messageJson(id: 2)];
    final messages = await api.repository().messages(7);
    expect(api.last.url.toString(), '$_base/tickets/7/messages');
    expect(messages.map((m) => m.id), [1, 2]);
  });

  test('open sends segment, description and files', () async {
    api
      ..status = 201
      ..reply = detailJson(id: 12, status: 'EM_FILA');

    final created = await api.repository().open(
      segment: 'DEFEITO_APP',
      description: 'O app fecha sozinho.',
      files: [PickedAttachment(name: 'tela.png', bytes: Uint8List(4))],
    );

    final body = utf8.decode(api.last.bodyBytes);
    expect(api.last.method, 'POST');
    expect(api.last.url.toString(), '$_base/tickets');
    expect(body, contains('name="segment"'));
    expect(body, contains('DEFEITO_APP'));
    expect(body, contains('name="description"'));
    expect(body, contains('O app fecha sozinho.'));
    expect(body, contains('filename="tela.png"'));
    expect(body, isNot(contains('chatbotConversationId')));
    expect(created.id, 12);
    expect(created.status, TicketStatus.emFila);
  });

  test('open sends the chatbot conversation id when there is one', () async {
    api
      ..status = 201
      ..reply = detailJson(id: 12, status: 'EM_FILA');

    await api.repository().open(
      segment: 'DEFEITO_APP',
      description: 'O app fecha sozinho.',
      files: const [],
      chatbotConversationId: 42,
    );

    final body = utf8.decode(api.last.bodyBytes);
    expect(body, contains('name="chatbotConversationId"\r\n\r\n42\r\n'));
  });

  test('sendMessage sends the body and files', () async {
    api
      ..status = 201
      ..reply = messageJson(id: 30, senderType: 'USER', body: 'Segue o PDF');

    final message = await api.repository().sendMessage(
      7,
      body: 'Segue o PDF',
      files: [PickedAttachment(name: 'nota.pdf', bytes: Uint8List(2))],
    );

    final body = utf8.decode(api.last.bodyBytes);
    expect(api.last.url.toString(), '$_base/tickets/7/messages');
    expect(body, contains('name="body"'));
    expect(body, contains('Segue o PDF'));
    expect(body, contains('content-type: application/pdf'));
    expect(message.id, 30);
  });

  test('confirm and reopen are POSTs without a body', () async {
    api.reply = detailJson(id: 7, status: 'FECHADO');
    final closed = await api.repository().confirm(7);
    expect(api.last.method, 'POST');
    expect(api.last.url.toString(), '$_base/tickets/7/confirm');
    expect(closed.status, TicketStatus.fechado);

    api = _Recorder()..reply = detailJson(id: 7, status: 'EM_ATENDIMENTO');
    final reopened = await api.repository().reopen(7);
    expect(api.last.url.toString(), '$_base/tickets/7/reopen');
    expect(reopened.status, TicketStatus.emAtendimento);
  });

  test('download uses the attachment path', () async {
    api.reply = [1, 2, 3];

    final bytes = await api.repository().download('/tickets/7/attachments/3');

    expect(api.last.url.toString(), '$_base/tickets/7/attachments/3');
    expect(bytes, [1, 2, 3]);
  });
}
