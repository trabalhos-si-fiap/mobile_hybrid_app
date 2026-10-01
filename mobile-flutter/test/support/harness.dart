import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/core/attachments/attachment_cache.dart';
import 'package:mobile_flutter/core/network/session_store.dart';
import 'package:mobile_flutter/core/network/token_store.dart';
import 'package:mobile_flutter/features/auth/data/auth_api.dart';
import 'package:mobile_flutter/features/notifications/notification_center.dart';

import 'fakes.dart';
import 'test_data.dart';

/// AppServices com falsos. Antes, no setUp:
/// FlutterSecureStorage.setMockInitialValues({}).
///
/// Um teste que liga o NotificationCenter precisa chamar
/// services.notificationCenter.stop() antes de terminar: o flutter_test
/// falha com timer pendente, e addTearDown roda tarde demais para isso.
AppServices testServices({
  FakeTicketRepository? tickets,
  FakeNotificationRepository? notifications,
  FakeLocalNotifier? notifier,
  FakeAttachmentPicker? picker,
  FakeFileOpener? opener,
  http.Client? authClient,
  List<int?>? openedFromNotification,
  Duration notificationInterval = const Duration(seconds: 30),
  DateTime Function()? clock,
}) {
  final ticketRepository = tickets ?? FakeTicketRepository();
  final notificationRepository = notifications ?? FakeNotificationRepository();
  final tokenStore = TokenStore();
  final sessionStore = SessionStore();
  return AppServices(
    navigatorKey: GlobalKey<NavigatorState>(),
    tokenStore: tokenStore,
    sessionStore: sessionStore,
    authApi: AuthApi(
      client: authClient ?? MockClient((_) async => http.Response('', 500)),
      tokenStore: tokenStore,
      sessionStore: sessionStore,
    ),
    tickets: ticketRepository,
    notifications: notificationRepository,
    notificationCenter: NotificationCenter(
      repository: notificationRepository,
      notifier: notifier ?? FakeLocalNotifier(),
      onOpen: (ticketId) => openedFromNotification?.add(ticketId),
      interval: notificationInterval,
      observeLifecycle: false,
    ),
    picker: picker ?? FakeAttachmentPicker(),
    opener: opener ?? FakeFileOpener(),
    attachments: AttachmentCache(ticketRepository.download),
    clock: clock ?? () => testNow,
  );
}

/// Monta [screen] dentro de AppScope e MaterialApp. As outras rotas viram o
/// texto `route:<nome>`, para conferir navegação.
Future<void> pumpScreen(
  WidgetTester tester,
  AppServices services,
  Widget screen,
) async {
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(
        navigatorKey: services.navigatorKey,
        navigatorObservers: [services.routeObserver],
        home: screen,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        ),
      ),
    ),
  );
  await tester.pump();
}
