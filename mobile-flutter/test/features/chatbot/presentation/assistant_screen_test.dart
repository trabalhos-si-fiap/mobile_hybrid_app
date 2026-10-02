import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/chatbot/domain/chatbot_models.dart';
import 'package:mobile_flutter/features/chatbot/presentation/assistant_screen.dart';
import 'package:mobile_flutter/features/tickets/domain/new_ticket_prefill.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';
import '../../../support/test_data.dart';

const _input = Key('assistant-input');
const _send = Key('assistant-send');

Key _option(String id) => Key('assistant-option-$id');

void main() {
  late FakeChatbotRepository chatbot;
  late AppServices services;
  late List<RouteSettings> pushed;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    chatbot = FakeChatbotRepository();
    services = testServices(chatbot: chatbot);
    pushed = [];
  });

  /// Abre o assistente por cima de uma tela "home", como Meus tickets faz.
  Future<void> open(WidgetTester tester) async {
    await pumpScreen(tester, services, const Text('home'), pushed: pushed);
    unawaited(
      services.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const AssistantScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(_input), text);
    await tester.tap(find.byKey(_send));
    await tester.pump();
  }

  String inputText(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(_input)).controller!.text;

  testWidgets('shows the greeting, the options and the input', (tester) async {
    await open(tester);

    expect(find.widgetWithText(AppBar, 'Mentor Edu'), findsOneWidget);
    expect(find.byKey(const Key('user-menu')), findsOneWidget);
    expect(find.text(greetingText), findsOneWidget);
    expect(find.byKey(_option('segment:DEFEITO_APP')), findsOneWidget);
    expect(find.byKey(_option('segment:PROBLEMA_PEDIDO')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_option('human')),
        matching: find.text('Falar com atendente'),
      ),
      findsOneWidget,
    );
    expect(find.text('Digite sua dúvida'), findsOneWidget);
    expect(find.byTooltip('Enviar'), findsOneWidget);
    expect(find.byKey(const Key('assistant-continue')), findsNothing);
    expect(find.byKey(const Key('assistant-done')), findsNothing);
  });

  testWidgets('a start failure offers a retry', (tester) async {
    chatbot.startError = const ApiException(ApiErrorKind.network);
    await pumpScreen(tester, services, const AssistantScreen());

    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
    expect(find.byKey(_input), findsNothing);

    chatbot.startError = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    expect(find.text(greetingText), findsOneWidget);
    expect(find.byKey(_input), findsOneWidget);
  });

  testWidgets('sends the typed text, shows the turn and clears the input', (
    tester,
  ) async {
    chatbot.sendResults.add(faqTurn());
    await open(tester);

    await typeAndSend(tester, 'Não consigo entrar');
    await tester.pump();

    expect(chatbot.sent, [const ChatbotReply.text('Não consigo entrar')]);
    expect(find.text('Não consigo entrar'), findsOneWidget);
    expect(find.text(faqAnswerText), findsOneWidget);
    expect(find.text('Isso resolveu sua dúvida?'), findsOneWidget);
    expect(find.byKey(_option('resolved')), findsOneWidget);
    expect(find.byKey(_option('human')), findsNothing);
    expect(inputText(tester), isEmpty);
  });

  testWidgets('while sending: typing notice, no options, input disabled', (
    tester,
  ) async {
    chatbot.sendResults.add(segmentTurn());
    await open(tester);
    chatbot.gate = Completer<void>();

    await tester.tap(find.byKey(_option('segment:DEFEITO_APP')));
    await tester.pump();

    expect(find.text('Mentor Edu está digitando…'), findsOneWidget);
    expect(find.byKey(_option('human')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(_input)).enabled, isFalse);
    expect(tester.widget<IconButton>(find.byKey(_send)).onPressed, isNull);

    chatbot.gate!.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Mentor Edu está digitando…'), findsNothing);
    expect(chatbot.sent, [const ChatbotReply.option('segment:DEFEITO_APP')]);
    expect(find.byKey(_option('faq:9')), findsOneWidget);
    expect(find.byKey(_option('menu')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_input)).enabled, isTrue);
  });

  testWidgets('a blank text is not sent', (tester) async {
    await open(tester);

    await typeAndSend(tester, '   ');

    expect(chatbot.sent, isEmpty);
  });

  testWidgets('a send failure keeps the text and the retry resends it', (
    tester,
  ) async {
    chatbot
      ..sendError = const ApiException(ApiErrorKind.server)
      ..sendResults.add(faqTurn());
    await open(tester);

    await typeAndSend(tester, 'Não consigo entrar');
    await tester.pump();

    expect(
      find.text('Erro no servidor. Tente de novo em instantes.'),
      findsOneWidget,
    );
    expect(inputText(tester), 'Não consigo entrar');
    expect(find.byKey(_option('human')), findsOneWidget);

    chatbot.sendError = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    await tester.pump();

    expect(chatbot.sent, [
      const ChatbotReply.text('Não consigo entrar'),
      const ChatbotReply.text('Não consigo entrar'),
    ]);
    expect(find.text(faqAnswerText), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
    expect(inputText(tester), isEmpty);
  });

  testWidgets('resolved: the input gives way to the button back to the list', (
    tester,
  ) async {
    chatbot.sendResults.addAll([faqTurn(), resolvedTurn()]);
    await open(tester);
    await typeAndSend(tester, 'Não consigo entrar');
    await tester.pump();

    await tester.tap(find.byKey(_option('resolved')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Que bom! Se precisar, é só chamar.'), findsOneWidget);
    expect(find.byKey(_input), findsNothing);
    expect(find.byKey(_option('not_resolved')), findsNothing);

    await tester.tap(find.byKey(const Key('assistant-done')));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(AssistantScreen), findsNothing);
  });

  testWidgets('handoff: continue replaces the assistant with the form', (
    tester,
  ) async {
    chatbot.sendResults.add(handoffTurn());
    await open(tester);

    await tester.tap(find.byKey(_option('human')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Vou te passar para um atendente. Revise o pedido, anexe evidências '
        'se tiver e envie.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(_input), findsNothing);

    await tester.tap(find.byKey(const Key('assistant-continue')));
    await tester.pumpAndSettle();

    expect(find.text('route:/tickets/new'), findsOneWidget);
    expect(
      pushed.single.arguments,
      const NewTicketPrefill(
        conversationId: 42,
        segment: 'DEFEITO_APP',
        description: 'O app fecha sozinho.',
      ),
    );

    services.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a 409 says the conversation ended and offers the way back', (
    tester,
  ) async {
    chatbot.sendError = const ApiException(ApiErrorKind.conflict);
    await open(tester);

    await typeAndSend(tester, 'Oi');
    await tester.pump();

    expect(find.text('Esta conversa foi encerrada.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
    expect(find.byKey(_input), findsNothing);
    expect(find.byKey(_option('human')), findsNothing);

    await tester.tap(find.byKey(const Key('assistant-done')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('scrolls to the last message on each turn', (tester) async {
    chatbot.sendResults.add(
      ChatbotTurn(
        conversationId: 42,
        state: ChatbotState.inicio,
        messages: [
          testUserMessage(2, 'Oi'),
          for (var i = 0; i < 20; i++) testBotMessage(10 + i, 'Linha $i'),
        ],
        options: const [
          ChatbotOption(id: 'human', label: 'Falar com atendente'),
        ],
        handoff: null,
      ),
    );
    await open(tester);

    await typeAndSend(tester, 'Oi');
    await tester.pump();
    await tester.pump();

    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent);
  });

  testWidgets('leaving during a send does not throw', (tester) async {
    chatbot.sendResults.add(segmentTurn());
    await open(tester);
    chatbot.gate = Completer<void>();
    await tester.tap(find.byKey(_option('segment:DEFEITO_APP')));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    chatbot.gate!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
