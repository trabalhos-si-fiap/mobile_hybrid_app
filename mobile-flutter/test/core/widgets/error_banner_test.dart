import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/widgets/error_banner.dart';

void main() {
  testWidgets('shows the message and retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorBanner(message: 'Sem conexão.', onRetry: () => retries++),
        ),
      ),
    );

    expect(find.text('Sem conexão.'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    expect(retries, 1);
  });

  testWidgets('has no retry button without onRetry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ErrorBanner(message: 'Falhou.', subtle: true)),
      ),
    );

    expect(find.text('Tentar de novo'), findsNothing);
  });
}
