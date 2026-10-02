import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/features/notifications/presentation/notifications_screen.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';
import '../../../support/test_data.dart';

void main() {
  late FakeNotificationRepository notifications;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    notifications = FakeNotificationRepository()
      ..all = [
        testNotification(id: 22, ticketId: 8, title: 'Ticket resolvido'),
        testNotification(id: 21, ticketId: 7, read: true),
      ];
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    testServices(notifications: notifications),
    const NotificationsScreen(),
  );

  testWidgets('lists the notifications', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('notification-22')), findsOneWidget);
    expect(find.byKey(const Key('notification-21')), findsOneWidget);
    expect(find.text('Ticket resolvido'), findsOneWidget);
    expect(find.text('há 10 min'), findsNWidgets(2));
  });

  testWidgets('shows an empty state', (tester) async {
    notifications.all = const [];
    await pump(tester);

    expect(find.text('Nenhuma notificação.'), findsOneWidget);
  });

  testWidgets('tapping marks it read and opens the ticket', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('notification-22')));
    await tester.pumpAndSettle();

    expect(notifications.calls, contains('read 22'));
    expect(find.text('route:/tickets/8'), findsOneWidget);
  });

  testWidgets('a double tap opens the ticket once', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('notification-22')));
    await tester.tap(find.byKey(const Key('notification-22')));
    await tester.pumpAndSettle();

    expect(find.text('route:/tickets/8'), findsOneWidget);
    expect(notifications.calls.where((c) => c == 'read 22'), hasLength(1));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('route:/tickets/8'), findsNothing);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('a failed mark-as-read reverts and explains', (tester) async {
    notifications.markReadError = const ApiException(ApiErrorKind.network);
    await pump(tester);

    await tester.tap(find.byKey(const Key('notification-22')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível marcar como lida. Sem conexão com o servidor.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('route:'), findsNothing);
    final markAll = tester.widget<IconButton>(
      find.byKey(const Key('mark-all-read')),
    );
    expect(markAll.onPressed, isNotNull, reason: 'o item voltou a não lido');
  });

  testWidgets('marks all as read', (tester) async {
    await pump(tester);

    expect(find.byTooltip('Marcar todas como lidas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mark-all-read')));
    await tester.pump();

    expect(notifications.calls, contains('read all'));
    final markAll = tester.widget<IconButton>(
      find.byKey(const Key('mark-all-read')),
    );
    expect(markAll.onPressed, isNull);
  });

  testWidgets('a load error offers a retry', (tester) async {
    notifications.listError = const ApiException(ApiErrorKind.server);
    await pump(tester);

    expect(
      find.text('Erro no servidor. Tente de novo em instantes.'),
      findsOneWidget,
    );
    notifications.listError = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    expect(find.byKey(const Key('notification-22')), findsOneWidget);
  });
}
