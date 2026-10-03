import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/auth/presentation/login_screen.dart';

import '../../../support/harness.dart';
import '../../../support/test_data.dart';

http.Client _authReturning(int status, {String role = 'USER'}) =>
    MockClient((_) async {
      if (status != 200) return http.Response('', status);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'accessToken': fakeJwt(role: role),
            'tokenType': 'Bearer',
            'user': {
              'id': 1,
              'name': 'Usuário Edu',
              'email': 'usuario@edu.com',
              'role': role,
            },
          }),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> login(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'usuario@edu.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'usuario123',
    );
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('a USER goes to the tickets', (tester) async {
    final services = testServices(authClient: _authReturning(200));
    await pumpScreen(tester, services, const LoginScreen());

    await login(tester);

    expect(find.text('route:/tickets'), findsOneWidget);
    expect(services.notificationCenter.isRunning, isTrue);
    expect(await services.sessionStore.readName(), 'Usuário Edu');
    services.notificationCenter.stop();
  });

  testWidgets('ADMIN and EMPLOYEE go to the dashboard', (tester) async {
    for (final role in ['ADMIN', 'EMPLOYEE']) {
      final services = testServices(
        authClient: _authReturning(200, role: role),
      );
      await pumpScreen(tester, services, const LoginScreen());

      await login(tester);

      expect(find.text('route:/home'), findsOneWidget, reason: role);
      expect(services.notificationCenter.isRunning, isFalse);
    }
  });

  testWidgets('a wrong password shows the message', (tester) async {
    await pumpScreen(
      tester,
      testServices(authClient: _authReturning(401)),
      const LoginScreen(),
    );

    await login(tester);

    expect(find.text('E-mail ou senha inválidos'), findsOneWidget);
  });

  testWidgets('an unknown role cannot use the app', (tester) async {
    final services = testServices(
      authClient: _authReturning(200, role: 'OUTRO'),
    );
    await pumpScreen(tester, services, const LoginScreen());

    await login(tester);

    expect(find.text('Esta conta não tem acesso ao app.'), findsOneWidget);
    expect(await services.tokenStore.readAccessToken(), isNull);
  });

  testWidgets('shows the expired session notice', (tester) async {
    final services = testServices();
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          navigatorKey: services.navigatorKey,
          home: const Text('home'),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const LoginScreen(),
          ),
        ),
      ),
    );

    services.navigatorKey.currentState!.pushNamed(
      '/login',
      arguments: const {'sessionExpired': true},
    );
    await tester.pumpAndSettle();

    expect(find.text('Sua sessão expirou. Entre de novo.'), findsOneWidget);
  });

  testWidgets('offers only e-mail and password: no sign-up, reset or social login', (
    tester,
  ) async {
    await pumpScreen(tester, testServices(), const LoginScreen());

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    for (final text in [
      'Esqueceu sua senha?',
      'Cadastro',
      'Ou entre com',
      'Google',
      'Apple',
    ]) {
      expect(find.text(text), findsNothing, reason: text);
    }
    expect(find.textContaining('Inscreva-se', findRichText: true), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}
