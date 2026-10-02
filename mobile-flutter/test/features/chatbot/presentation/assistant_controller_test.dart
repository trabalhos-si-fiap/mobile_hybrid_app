import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/features/chatbot/domain/chatbot_models.dart';
import 'package:mobile_flutter/features/chatbot/presentation/assistant_controller.dart';
import 'package:mobile_flutter/features/tickets/domain/new_ticket_prefill.dart';

import '../../../support/fakes.dart';
import '../../../support/test_data.dart';

void main() {
  late FakeChatbotRepository chatbot;
  late AssistantController controller;

  setUp(() {
    chatbot = FakeChatbotRepository();
    controller = AssistantController(repository: chatbot);
  });

  tearDown(() => controller.dispose());

  int sendCalls() => chatbot.calls.where((c) => c.startsWith('send')).length;

  test('start shows the greeting and its options', () async {
    await controller.start();

    expect(controller.state, ChatbotState.inicio);
    expect(controller.messages.single.body, greetingText);
    expect(controller.options.map((o) => o.id), [
      'segment:DEFEITO_APP',
      'segment:PROBLEMA_PEDIDO',
      'human',
    ]);
    expect(controller.acceptsReplies, isTrue);
    expect(controller.handedOff, isFalse);
    expect(controller.finished, isFalse);
  });

  test('a start failure keeps the message and start tries again', () async {
    chatbot.startError = const ApiException(ApiErrorKind.network);
    await controller.start();

    expect(controller.state, isNull);
    expect(controller.startError, 'Sem conexão com o servidor.');
    expect(controller.finished, isFalse);

    chatbot.startError = null;
    await controller.start();

    expect(controller.startError, isNull);
    expect(controller.state, ChatbotState.inicio);
  });

  test('a 401 on start shows no error', () async {
    chatbot.startError = const ApiException(ApiErrorKind.unauthorized);
    await controller.start();

    expect(controller.startError, isNull);
  });

  test('sends the trimmed text and appends the turn', () async {
    chatbot.sendResults.add(faqTurn());
    await controller.start();

    final sent = await controller.sendText('  Não consigo entrar \n');

    expect(sent, isTrue);
    expect(chatbot.calls, ['start', 'send 42']);
    expect(chatbot.sent, [const ChatbotReply.text('Não consigo entrar')]);
    expect(controller.state, ChatbotState.confirmacao);
    expect(controller.messages.map((m) => m.id), [1, 4, 5, 6]);
    expect(controller.options.map((o) => o.id), ['resolved', 'not_resolved']);
  });

  test('a blank text is not sent', () async {
    await controller.start();

    expect(await controller.sendText('   '), isFalse);
    expect(sendCalls(), 0);
  });

  test('choosing an option sends its id', () async {
    chatbot.sendResults.add(segmentTurn());
    await controller.start();

    await controller.choose(controller.options.first);

    expect(chatbot.sent, [const ChatbotReply.option('segment:DEFEITO_APP')]);
    expect(controller.state, ChatbotState.segmento);
    expect(controller.options.map((o) => o.id), ['faq:9', 'menu', 'human']);
  });

  test('sending is on while the request is in flight', () async {
    chatbot.sendResults.add(segmentTurn());
    await controller.start();
    chatbot.gate = Completer<void>();

    final pending = controller.choose(controller.options.first);
    expect(controller.sending, isTrue);

    chatbot.gate!.complete();
    await pending;
    expect(controller.sending, isFalse);
  });

  test('sends only once while a send is in flight', () async {
    chatbot.sendResults.add(segmentTurn());
    await controller.start();
    chatbot.gate = Completer<void>();

    final first = controller.choose(controller.options.first);
    final second = await controller.sendText('Oi');
    chatbot.gate!.complete();
    await first;

    expect(second, isFalse);
    expect(sendCalls(), 1);
  });

  test('a send failure keeps the conversation and retry resends the same '
      'reply', () async {
    chatbot.sendError = const ApiException(ApiErrorKind.server);
    chatbot.sendResults.add(faqTurn());
    await controller.start();

    expect(await controller.sendText('Não consigo entrar'), isFalse);
    expect(
      controller.sendError,
      'Erro no servidor. Tente de novo em instantes.',
    );
    expect(controller.state, ChatbotState.inicio);
    expect(controller.options, hasLength(3));
    expect(controller.acceptsReplies, isTrue);

    chatbot.sendError = null;
    final resent = await controller.retry();

    expect(resent, const ChatbotReply.text('Não consigo entrar'));
    expect(chatbot.sent, [
      const ChatbotReply.text('Não consigo entrar'),
      const ChatbotReply.text('Não consigo entrar'),
    ]);
    expect(controller.sendError, isNull);
    expect(controller.state, ChatbotState.confirmacao);
    expect(await controller.retry(), isNull);
  });

  test('a 409 means the conversation was closed elsewhere', () async {
    chatbot.sendError = const ApiException(ApiErrorKind.conflict);
    await controller.start();

    await controller.choose(controller.options.last);

    expect(controller.closed, isTrue);
    expect(controller.sendError, isNull);
    expect(controller.acceptsReplies, isFalse);
    expect(controller.finished, isTrue);
    expect(await controller.retry(), isNull);
  });

  test('a 401 on send shows no error', () async {
    chatbot.sendError = const ApiException(ApiErrorKind.unauthorized);
    await controller.start();

    await controller.sendText('Oi');

    expect(controller.sendError, isNull);
    expect(controller.closed, isFalse);
  });

  test('the handoff ends the replies and carries the prefill', () async {
    chatbot.sendResults.add(handoffTurn());
    await controller.start();

    await controller.choose(controller.options.last);

    expect(controller.state, ChatbotState.encaminhamento);
    expect(controller.acceptsReplies, isFalse);
    expect(controller.handedOff, isTrue);
    expect(controller.finished, isFalse);
    expect(
      controller.prefill,
      const NewTicketPrefill(
        conversationId: 42,
        segment: 'DEFEITO_APP',
        description: 'O app fecha sozinho.',
      ),
    );
  });

  test('a handoff without a segment keeps it empty in the prefill', () async {
    chatbot.sendResults.add(handoffTurn(segment: null, description: ''));
    await controller.start();

    await controller.choose(controller.options.last);

    expect(controller.prefill!.segment, isNull);
    expect(controller.prefill!.description, '');
  });

  test('resolved finishes the conversation', () async {
    chatbot.sendResults.addAll([faqTurn(), resolvedTurn()]);
    await controller.start();
    await controller.sendText('Não consigo entrar');

    await controller.choose(controller.options.first);

    expect(chatbot.sent.last, const ChatbotReply.option('resolved'));
    expect(controller.state, ChatbotState.resolvida);
    expect(controller.finished, isTrue);
    expect(controller.prefill, isNull);
    expect(await controller.sendText('Mais uma'), isFalse);
    expect(sendCalls(), 2);
  });

  test('disposing during a send does not throw', () async {
    chatbot.sendResults.add(segmentTurn());
    await controller.start();
    chatbot.gate = Completer<void>();

    final pending = controller.choose(controller.options.first);
    controller.dispose();
    chatbot.gate!.complete();

    expect(await pending, isTrue);
    controller = AssistantController(repository: chatbot);
  });
}
