import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/chatbot/domain/chatbot_models.dart';

import '../../../support/json_fixtures.dart';

void main() {
  test('enums parse the API values and refuse unknown ones', () {
    expect(ChatbotState.fromApi('ENCAMINHAMENTO'), ChatbotState.encaminhamento);
    expect(ChatbotSender.fromApi('USER'), ChatbotSender.user);
    expect(() => ChatbotState.fromApi('PERDIDA'), throwsFormatException);
    expect(() => ChatbotSender.fromApi('SYSTEM'), throwsFormatException);
  });

  test('only INICIO, SEGMENTO and CONFIRMACAO accept replies', () {
    expect(
      [
        for (final state in ChatbotState.values)
          if (state.acceptsReplies) state,
      ],
      [ChatbotState.inicio, ChatbotState.segmento, ChatbotState.confirmacao],
    );
  });

  test('ChatbotTurn.fromJson reads the messages and the options', () {
    final turn = ChatbotTurn.fromJson(
      chatbotTurnJson(
        state: 'CONFIRMACAO',
        messages: [
          chatbotMessageJson(id: 2, sender: 'USER', body: 'Não consigo entrar'),
          chatbotMessageJson(id: 3, body: 'Confira o e-mail e a senha.'),
        ],
        options: [
          {'id': 'resolved', 'label': 'Resolveu'},
          {'id': 'not_resolved', 'label': 'Não resolveu'},
        ],
      ),
    );

    expect(turn.conversationId, 42);
    expect(turn.state, ChatbotState.confirmacao);
    expect(turn.messages.map((m) => m.id), [2, 3]);
    expect(turn.messages.first.sender, ChatbotSender.user);
    expect(turn.messages.first.body, 'Não consigo entrar');
    expect(turn.messages.first.createdAt, DateTime.utc(2026, 9, 30, 12, 59));
    expect(turn.messages.last.sender, ChatbotSender.bot);
    expect(turn.options.map((o) => o.id), ['resolved', 'not_resolved']);
    expect(turn.options.last.label, 'Não resolveu');
    expect(turn.handoff, isNull);
  });

  test('ChatbotTurn.fromJson reads the handoff, with or without a segment', () {
    final withSegment = ChatbotTurn.fromJson(
      chatbotTurnJson(
        state: 'ENCAMINHAMENTO',
        options: const [],
        handoff: {'segment': 'PROBLEMA_PEDIDO', 'description': 'Veio errado.'},
      ),
    );
    expect(withSegment.options, isEmpty);
    expect(withSegment.handoff!.segment, 'PROBLEMA_PEDIDO');
    expect(withSegment.handoff!.description, 'Veio errado.');

    final withoutSegment = ChatbotTurn.fromJson(
      chatbotTurnJson(
        state: 'ENCAMINHAMENTO',
        options: const [],
        handoff: {'segment': null, 'description': ''},
      ),
    );
    expect(withoutSegment.handoff!.segment, isNull);
    expect(withoutSegment.handoff!.description, '');
  });

  test('a reply carries exactly one of text and option', () {
    expect(const ChatbotReply.text('Oi').toJson(), {'text': 'Oi'});
    expect(const ChatbotReply.option('human').toJson(), {'optionId': 'human'});
    expect(const ChatbotReply.text('Oi'), const ChatbotReply.text('Oi'));
    expect(
      const ChatbotReply.text('human'),
      isNot(const ChatbotReply.option('human')),
    );
  });
}
