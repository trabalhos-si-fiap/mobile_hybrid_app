import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/app_services.dart';

import '../support/fakes.dart';
import '../support/harness.dart';
import '../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('notificationRoute', () {
    expect(AppServices.notificationRoute(7), '/tickets/7');
    expect(AppServices.notificationRoute(null), '/notifications');
  });

  testWidgets('logout stops the center, clears the cache and the tokens', (
    tester,
  ) async {
    final tickets = FakeTicketRepository();
    final opener = FakeFileOpener();
    final services = testServices(tickets: tickets, opener: opener);
    await services.tokenStore.save(accessToken: 'token', refreshToken: '');
    await services.sessionStore.saveName('Ana');
    await pumpScreen(tester, services, const Text('home'));
    await services.startUserSession();
    await services.attachments.load(testAttachment());

    await services.logout();
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
    expect(await services.tokenStore.readAccessToken(), isNull);
    expect(await services.sessionStore.readName(), isNull);
    expect(services.notificationCenter.isRunning, isFalse);
    await services.attachments.load(testAttachment());
    expect(tickets.calls.where((c) => c.startsWith('download')), hasLength(2));
    expect(opener.clearCalls, 1);
  });

  testWidgets('sessionExpired after a voluntary logout shows no notice', (
    tester,
  ) async {
    final services = testServices();
    final logins = <RouteSettings>[];
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          navigatorKey: services.navigatorKey,
          home: const Text('home'),
          onGenerateRoute: (settings) {
            if (settings.name == '/login') logins.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Text('login'),
            );
          },
        ),
      ),
    );
    await services.startUserSession();
    await services.logout();
    await tester.pumpAndSettle();

    services.sessionExpired();
    await tester.pumpAndSettle();

    expect(logins, hasLength(1));
    expect(logins.single.arguments, isNull);
  });

  testWidgets('sessionExpired goes to login with the notice argument', (
    tester,
  ) async {
    final opener = FakeFileOpener();
    final services = testServices(opener: opener);
    RouteSettings? login;
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          navigatorKey: services.navigatorKey,
          home: const Text('home'),
          onGenerateRoute: (settings) {
            if (settings.name == '/login') login = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Text('login'),
            );
          },
        ),
      ),
    );
    await services.startUserSession();

    services.sessionExpired();
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    expect(login!.arguments, {'sessionExpired': true});
    expect(services.notificationCenter.isRunning, isFalse);
    expect(opener.clearCalls, 1);
  });

  testWidgets('a failure deleting the PDFs does not block the logout', (
    tester,
  ) async {
    final opener = FakeFileOpener()..clearError = StateError('ocupado');
    final services = testServices(opener: opener);
    await pumpScreen(tester, services, const Text('home'));

    await services.logout();
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
    expect(opener.clearCalls, 1);
  });

  testWidgets('AppScope.of finds the services', (tester) async {
    final services = testServices();
    late AppServices found;
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: Builder(
          builder: (context) {
            found = AppScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(found, same(services));
  });
}
