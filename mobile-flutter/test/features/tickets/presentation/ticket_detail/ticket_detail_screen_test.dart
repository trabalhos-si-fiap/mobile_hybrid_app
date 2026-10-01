import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/core/utils/time_format.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';
import 'package:mobile_flutter/features/tickets/presentation/ticket_detail/ticket_detail_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/harness.dart';
import '../../../../support/test_data.dart';

void main() {
  late FakeTicketRepository tickets;
  late FakeAttachmentPicker picker;
  late AppServices services;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tickets = FakeTicketRepository()
      ..detailResult = testDetail(
        attachments: [
          testAttachment(
            id: 4,
            fileName: 'nota.pdf',
            contentType: 'application/pdf',
          ),
        ],
      )
      ..messagesResult = [
        testMessage(id: 1, body: 'Olá! Já estou vendo.'),
        testMessage(
          id: 2,
          senderType: SenderType.user,
          senderName: 'Ana',
          body: 'Obrigada!',
        ),
        testMessage(
          id: 3,
          senderType: SenderType.system,
          senderName: 'Sistema',
          body: 'Ticket reaberto pelo usuário',
        ),
      ];
    picker = FakeAttachmentPicker();
    services = testServices(tickets: tickets, picker: picker);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, services, const TicketDetailScreen(ticketId: 7));
  }

  int callsOf(String prefix) =>
      tickets.calls.where((c) => c.startsWith(prefix)).length;

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('composer-input')), text);
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();
  }

  testWidgets('shows the header, the request and the conversation', (
    tester,
  ) async {
    await pump(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('ticket-title'))).data,
      '#7',
    );
    expect(find.text('Defeito no App'), findsOneWidget);
    expect(find.text('Em atendimento'), findsOneWidget);
    expect(find.text('Atendente: Dev'), findsOneWidget);
    expect(
      find.text('Aberto em ${formatDateTime(DateTime.utc(2026, 9, 30, 12))}'),
      findsOneWidget,
    );
    expect(
      find.text('Prazo: até ${formatDateTime(DateTime.utc(2026, 9, 30, 17))}'),
      findsOneWidget,
    );
    expect(find.text('Sua solicitação'), findsOneWidget);
    expect(
      find.text('O app fecha sozinho ao abrir o carrinho.'),
      findsOneWidget,
    );
    expect(find.text('nota.pdf'), findsOneWidget);
    expect(find.text('Olá! Já estou vendo.'), findsOneWidget);
    expect(find.text('Obrigada!'), findsOneWidget);
    expect(find.text('Ticket reaberto pelo usuário'), findsOneWidget);
    expect(find.byKey(const Key('resolution-card')), findsNothing);
  });

  testWidgets('polls every 10 seconds', (tester) async {
    await pump(tester);
    expect(callsOf('detail'), 1);

    await tester.pump(const Duration(seconds: 10));

    expect(callsOf('detail'), 2);
    expect(callsOf('messages'), 2);
  });

  testWidgets('RESOLVIDO asks first, then confirms and closes', (tester) async {
    tickets.detailResult = testDetail(
      status: TicketStatus.resolvido,
      slaStatus: SlaStatus.cumprido,
    );
    await pump(tester);

    expect(
      find.text(
        'O atendente marcou como resolvido. Seu problema foi resolvido?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar o ticket?'), findsOneWidget);
    expect(
      find.text('Depois de encerrado, o ticket não pode ser reaberto.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(callsOf('confirm'), 0);

    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();

    expect(callsOf('confirm'), 1);
    expect(find.text('Fechado'), findsOneWidget);
    expect(find.byKey(const Key('resolution-card')), findsNothing);
    expect(
      find.text('Ticket fechado. Abra um novo se precisar.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('composer-input')), findsNothing);
  });

  testWidgets('RESOLVIDO can be reopened', (tester) async {
    tickets.detailResult = testDetail(status: TicketStatus.resolvido);
    await pump(tester);

    await tester.tap(find.byKey(const Key('reopen-ticket')));
    await tester.pumpAndSettle();

    expect(callsOf('reopen'), 1);
    expect(find.text('Em atendimento'), findsOneWidget);
    expect(find.byKey(const Key('resolution-card')), findsNothing);
  });

  testWidgets('RESOLVIDO still accepts messages', (tester) async {
    tickets.detailResult = testDetail(status: TicketStatus.resolvido);
    await pump(tester);

    expect(find.byKey(const Key('composer-input')), findsOneWidget);
  });

  testWidgets('sends text and attachments, then clears them', (tester) async {
    picker.next = [pickedPdf()];
    await pump(tester);

    await tester.tap(find.byKey(const Key('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach-pdf')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remover nota.pdf'), findsOneWidget);

    await typeAndSend(tester, '  Segue o PDF  ');
    await tester.pump();

    expect(tickets.sentBodies, ['Segue o PDF']);
    expect(tickets.sentFiles.single.single.name, 'nota.pdf');
    expect(find.byTooltip('Remover nota.pdf'), findsNothing);
    final input = tester.widget<TextField>(
      find.byKey(const Key('composer-input')),
    );
    expect(input.controller!.text, isEmpty);
    expect(callsOf('messages'), 2);
  });

  testWidgets('an empty message is not sent', (tester) async {
    await pump(tester);

    await typeAndSend(tester, '   ');

    expect(find.text('Escreva uma mensagem.'), findsOneWidget);
    expect(callsOf('send'), 0);
  });

  testWidgets('keeps the text typed during a send', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);

    await typeAndSend(tester, 'primeira');
    await tester.enterText(find.byKey(const Key('composer-input')), 'segunda');
    tickets.gate!.complete();
    await tester.pump();
    await tester.pump();

    final input = tester.widget<TextField>(
      find.byKey(const Key('composer-input')),
    );
    expect(input.controller!.text, 'segunda');
  });

  testWidgets('sends only once on a double tap', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);

    await tester.enterText(find.byKey(const Key('composer-input')), 'oi');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();
    tickets.gate!.complete();
    await tester.pump();

    expect(callsOf('send'), 1);
  });

  testWidgets('confirms only once on a double tap', (tester) async {
    tickets.detailResult = testDetail(status: TicketStatus.resolvido);
    tickets.gate = Completer<void>();
    await pump(tester);

    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('confirm-dialog-ok')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
      await tester.pumpAndSettle();
    }
    tickets.gate!.complete();
    await tester.pumpAndSettle();

    expect(callsOf('confirm'), 1);
  });

  testWidgets('a 409 explains and reloads', (tester) async {
    tickets.actionError = const ApiException(ApiErrorKind.conflict);
    await pump(tester);

    await typeAndSend(tester, 'oi');
    await tester.pump();

    expect(
      find.text('O ticket mudou de situação. A tela foi atualizada.'),
      findsOneWidget,
    );
    expect(callsOf('detail'), 2);
  });

  testWidgets('a 404 shows the not found state', (tester) async {
    tickets.detailError = const ApiException(ApiErrorKind.notFound);
    await pump(tester);

    expect(find.text('Ticket não encontrado.'), findsOneWidget);
    expect(find.text('Voltar para meus tickets'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(callsOf('detail'), 1, reason: 'o polling parou');
  });

  testWidgets('a first load error offers a retry', (tester) async {
    tickets.detailError = const ApiException(ApiErrorKind.server);
    await pump(tester);

    expect(
      find.text('Erro no servidor. Tente de novo em instantes.'),
      findsOneWidget,
    );
    tickets.detailError = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    expect(find.text('Sua solicitação'), findsOneWidget);
  });

  testWidgets('disposing during a send does not throw', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);
    await typeAndSend(tester, 'oi');

    await tester.pumpWidget(const SizedBox());
    tickets.gate!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('is the current ticket while open', (tester) async {
    await pump(tester);
    expect(services.notificationCenter.currentTicketId, 7);

    await tester.pumpWidget(const SizedBox());
    expect(services.notificationCenter.currentTicketId, isNull);
  });

  testWidgets('reloads at once when the center reports this ticket', (
    tester,
  ) async {
    final notifications = FakeNotificationRepository()
      ..unreadResponses.addAll([
        [],
        [testNotification(id: 22, ticketId: 7)],
      ]);
    services = testServices(
      tickets: tickets,
      notifications: notifications,
      notificationInterval: const Duration(seconds: 5),
    );
    await pump(tester);
    await services.notificationCenter.start();
    await tester.pump();
    expect(callsOf('detail'), 1);

    await tester.pump(const Duration(seconds: 5));

    expect(callsOf('detail'), 2);
    services.notificationCenter.stop();
  });
}
