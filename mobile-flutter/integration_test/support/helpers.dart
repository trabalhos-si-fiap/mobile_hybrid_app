import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Espera [finder] aparecer, em tempo real (polling da API incluso).
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) => waitUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  timeout: timeout,
  description: '$finder',
);

Future<void> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  String description = 'condição',
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TestFailure('Não aconteceu em ${timeout.inSeconds} s: $description');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> login(WidgetTester tester, String email, String password) async {
  await waitFor(tester, find.byKey(const Key('login-email')));
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tapVisible(tester, find.byKey(const Key('login-submit')));
}

Future<void> logout(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('user-menu')));
  await waitFor(tester, find.byKey(const Key('logout')));
  // Deixa a animação do menu terminar antes do toque.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('logout')));
  await waitFor(tester, find.byKey(const Key('login-email')));
}

/// Texto de um Text com [key], ou nulo se ele não está na tela.
String? textOf(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
}

/// Id do ticket aberto na tela de detalhe (título "#12").
Future<int> ticketIdOnScreen(WidgetTester tester) async {
  await waitFor(tester, find.byKey(const Key('ticket-title')));
  return int.parse(textOf(tester, const Key('ticket-title'))!.substring(1));
}
