import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';
import 'package:mobile_flutter/features/tickets/presentation/my_tickets/my_tickets_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/harness.dart';
import '../../../../support/test_data.dart';

void main() {
  late FakeTicketRepository tickets;
  late AppServices services;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tickets = FakeTicketRepository()
      ..mineResult = [
        testSummary(
          id: 9,
          status: TicketStatus.emAtendimento,
          assigneeName: 'Dev',
        ),
        testSummary(id: 8, status: TicketStatus.resolvido, assigneeName: 'Dev'),
        testSummary(id: 7),
      ];
    services = testServices(tickets: tickets);
  });

  int mineCalls() => tickets.calls.where((c) => c == 'mine').length;

  testWidgets('shows a skeleton while loading', (tester) async {
    tickets.readGate = Completer<void>();
    await pumpScreen(tester, services, const MyTicketsScreen());

    expect(find.bySemanticsLabel('Carregando tickets'), findsOneWidget);

    tickets.readGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Carregando tickets'), findsNothing);
    expect(find.byKey(const Key('ticket-card-9')), findsOneWidget);
  });

  testWidgets('lists the tickets with RESOLVIDO first', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    final y8 = tester.getTopLeft(find.byKey(const Key('ticket-card-8'))).dy;
    final y9 = tester.getTopLeft(find.byKey(const Key('ticket-card-9'))).dy;
    final y7 = tester.getTopLeft(find.byKey(const Key('ticket-card-7'))).dy;
    expect(y8, lessThan(y9));
    expect(y9, lessThan(y7));

    expect(find.text('#8 · Defeito no App'), findsOneWidget);
    expect(find.text('Confirme a solução'), findsOneWidget);
    expect(find.text('Resolvido: confirme'), findsOneWidget);
    expect(find.text('Atendente: Dev'), findsNWidgets(2));
    expect(find.text('Aguardando atendente'), findsNWidgets(2));
    expect(find.text('Atualizado há 5 min'), findsNWidgets(3));
  });

  testWidgets('shows an empty state', (tester) async {
    tickets.mineResult = const [];
    await pumpScreen(tester, services, const MyTicketsScreen());

    expect(find.text('Você ainda não abriu tickets'), findsOneWidget);
  });

  testWidgets('a first load error offers a retry', (tester) async {
    tickets.mineError = const ApiException(ApiErrorKind.server);
    await pumpScreen(tester, services, const MyTicketsScreen());

    expect(
      find.text('Erro no servidor. Tente de novo em instantes.'),
      findsOneWidget,
    );

    tickets.mineError = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    expect(find.byKey(const Key('ticket-card-9')), findsOneWidget);
  });

  testWidgets('a polling error keeps the list and shows the offline banner', (
    tester,
  ) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    tickets.mineError = const ApiException(ApiErrorKind.network);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Sem conexão. Tentando de novo…'), findsOneWidget);
    expect(find.byKey(const Key('ticket-card-9')), findsOneWidget);
  });

  testWidgets('ignores unauthorized errors', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    tickets.mineError = const ApiException(ApiErrorKind.unauthorized);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Sem conexão. Tentando de novo…'), findsNothing);
    expect(find.text('Tentar de novo'), findsNothing);
    expect(find.byKey(const Key('ticket-card-9')), findsOneWidget);
  });

  testWidgets('opens a ticket and reloads on the way back', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());
    expect(mineCalls(), 1);

    await tester.tap(find.byKey(const Key('ticket-card-8')));
    await tester.pumpAndSettle();
    expect(find.text('route:/tickets/8'), findsOneWidget);

    services.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(mineCalls(), 2);
  });

  testWidgets('the button opens the new ticket screen', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    await tester.tap(find.byKey(const Key('new-ticket-button')));
    await tester.pumpAndSettle();

    expect(find.text('route:/tickets/new'), findsOneWidget);
  });

  testWidgets('reloads when the notification center reports news', (
    tester,
  ) async {
    final notifications = FakeNotificationRepository()
      ..unreadResponses.addAll([
        [],
        [testNotification(id: 22, ticketId: 9)],
      ]);
    services = testServices(
      tickets: tickets,
      notifications: notifications,
      notificationInterval: const Duration(seconds: 5),
    );
    await pumpScreen(tester, services, const MyTicketsScreen());
    await services.notificationCenter.start();
    await tester.pump();
    expect(mineCalls(), 1);

    await tester.pump(const Duration(seconds: 5));

    expect(mineCalls(), 2);
    services.notificationCenter.stop();
  });

  testWidgets('has the bell and the account menu', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    expect(find.text('Meus tickets'), findsOneWidget);
    expect(find.byKey(const Key('bell')), findsOneWidget);
    expect(find.byKey(const Key('user-menu')), findsOneWidget);
  });
}
