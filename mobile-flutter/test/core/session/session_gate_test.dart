import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/session/session_gate.dart';

import '../../support/harness.dart';
import '../../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('without a token goes to login', (tester) async {
    await pumpScreen(tester, testServices(), const SessionGate());
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
  });

  testWidgets('a USER goes to the tickets and starts the notifications', (
    tester,
  ) async {
    final services = testServices();
    await services.tokenStore.save(accessToken: fakeJwt(), refreshToken: '');

    await pumpScreen(tester, services, const SessionGate());
    await tester.pumpAndSettle();

    expect(find.text('route:/tickets'), findsOneWidget);
    expect(services.notificationCenter.isRunning, isTrue);
    services.notificationCenter.stop();
  });

  testWidgets('staff goes to the admin dashboard', (tester) async {
    final services = testServices();
    await services.tokenStore.save(
      accessToken: fakeJwt(role: 'EMPLOYEE'),
      refreshToken: '',
    );

    await pumpScreen(tester, services, const SessionGate());
    await tester.pumpAndSettle();

    expect(find.text('route:/home'), findsOneWidget);
    expect(services.notificationCenter.isRunning, isFalse);
  });

  testWidgets('an expired token is dropped', (tester) async {
    final services = testServices();
    await services.tokenStore.save(
      accessToken: fakeJwt(
        expiresAt: testNow.subtract(const Duration(minutes: 1)),
      ),
      refreshToken: '',
    );

    await pumpScreen(tester, services, const SessionGate());
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
    expect(await services.tokenStore.readAccessToken(), isNull);
  });
}
