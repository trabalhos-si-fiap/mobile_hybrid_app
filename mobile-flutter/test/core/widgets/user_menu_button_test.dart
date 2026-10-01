import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/widgets/user_menu_button.dart';

import '../../support/harness.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Sair ends the session and goes to login', (tester) async {
    final services = testServices();
    await services.tokenStore.save(accessToken: 'token', refreshToken: '');
    await pumpScreen(
      tester,
      services,
      Scaffold(appBar: AppBar(actions: const [UserMenuButton()])),
    );

    await tester.tap(find.byKey(const Key('user-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
    expect(await services.tokenStore.readAccessToken(), isNull);
  });
}
