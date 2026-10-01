import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/notifications/presentation/bell_button.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';
import '../../../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('shows the unread count and opens the list', (tester) async {
    final notifications = FakeNotificationRepository()
      ..unreadResponses.add([
        testNotification(id: 1),
        testNotification(id: 2),
        testNotification(id: 3),
      ]);
    final services = testServices(notifications: notifications);
    await pumpScreen(
      tester,
      services,
      Scaffold(appBar: AppBar(actions: const [BellButton()])),
    );
    await services.notificationCenter.start();
    await tester.pump();

    expect(find.byKey(const Key('unread-count')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('unread-count'))).data,
      '3',
    );
    expect(find.bySemanticsLabel('3 notificações não lidas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    expect(find.text('route:/notifications'), findsOneWidget);
    services.notificationCenter.stop();
  });
}
