import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_flutter/app.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/tickets/presentation/ticket_detail/message_bubble.dart';

import 'support/e2e_api.dart';
import 'support/e2e_fakes.dart';
import 'support/helpers.dart';

Finder _bubble(String text) =>
    find.descendant(of: find.byType(MessageBubble), matching: find.text(text));

// A árvore de semântica não está ligada no aparelho: acha o rótulo no widget.
Finder _imageTile(String name) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == 'Imagem $name',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late E2eApi user;
  late E2eApi dev;
  AppServices? services;

  setUpAll(() async {
    user = await E2eApi.login(userEmail, userPassword);
    dev = await E2eApi.login(devEmail, devPassword);
  });

  setUp(() async {
    await dev.setPresence('OFFLINE');
    await user.markAllRead();
  });

  tearDown(() async {
    services?.notificationCenter.stop();
    await services?.tokenStore.clear();
    await services?.sessionStore.clear();
    await dev.setPresence('OFFLINE');
  });

  Future<void> startApp(WidgetTester tester) async {
    final app = AppServices.production(
      picker: E2eAttachmentPicker(),
      notifier: E2eLocalNotifier(),
    );
    services = app;
    await app.tokenStore.clear();
    await tester.pumpWidget(EduApp(services: app));
    await waitFor(tester, find.byKey(const Key('login-email')));
  }

  testWidgets('access: USER to the tickets, EMPLOYEE to the dashboard', (
    tester,
  ) async {
    await startApp(tester);

    await login(tester, userEmail, 'senha-errada');
    await waitFor(tester, find.text('E-mail ou senha inválidos'));

    await login(tester, userEmail, userPassword);
    await waitFor(tester, find.text('Meus tickets'));

    await logout(tester);
    await login(tester, devEmail, devPassword);
    await waitFor(tester, find.text('Painel Administrativo'));
  });

  testWidgets('full flow: open with a photo, talk with a PDF, confirm', (
    tester,
  ) async {
    await dev.setPresence('ONLINE');
    await startApp(tester);
    await login(tester, userEmail, userPassword);
    await waitFor(tester, find.byKey(const Key('new-ticket-button')));

    await tester.tap(find.byKey(const Key('new-ticket-button')));
    await waitFor(tester, find.byKey(const Key('segment-DEFEITO_APP')));
    await tester.tap(find.byKey(const Key('segment-DEFEITO_APP')));
    await tester.enterText(
      find.byKey(const Key('description-input')),
      'E2E: o app fecha ao abrir o carrinho.',
    );
    await tapVisible(tester, find.byKey(const Key('attach-camera')));
    await waitFor(tester, find.byTooltip('Remover tela.png'));
    await tapVisible(tester, find.byKey(const Key('submit-ticket')));

    final id = await ticketIdOnScreen(tester);
    await waitFor(tester, find.text('Atendente: E2E Atendente'));
    await waitFor(tester, _imageTile('tela.png'));

    await dev.assume(id);
    await dev.sendMessage(id, 'Olá! Já estou vendo o seu caso.');
    await waitFor(
      tester,
      _bubble('Olá! Já estou vendo o seu caso.'),
      timeout: const Duration(seconds: 25),
    );
    await waitFor(tester, find.text('Em atendimento'));

    await tester.tap(find.byKey(const Key('composer-attach')));
    await waitFor(tester, find.byKey(const Key('attach-pdf')));
    // Deixa a folha de anexos terminar de subir antes do toque.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('attach-pdf')));
    await waitFor(tester, find.byTooltip('Remover comprovante.pdf'));
    await tester.enterText(
      find.byKey(const Key('composer-input')),
      'Segue o comprovante.',
    );
    await tester.tap(find.byKey(const Key('send-button')));
    await waitFor(tester, _bubble('Segue o comprovante.'));
    final sent = (await dev.messages(id)).cast<Map<String, dynamic>>().last;
    expect(sent['body'], 'Segue o comprovante.');
    expect(
      (sent['attachments'] as List<dynamic>).single['fileName'],
      'comprovante.pdf',
    );

    await dev.resolve(id);
    await waitFor(
      tester,
      find.byKey(const Key('resolution-card')),
      timeout: const Duration(seconds: 25),
    );
    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await waitFor(tester, find.byKey(const Key('confirm-dialog-ok')));
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await waitFor(tester, find.byKey(const Key('composer-closed')));

    await waitFor(tester, find.text('Fechado'));
    expect((await user.ticket(id))['status'], 'FECHADO');
  });

  testWidgets('reopen: a resolved ticket goes back to the attendant', (
    tester,
  ) async {
    await dev.setPresence('ONLINE');
    final id = await user.openTicket('DEFEITO_APP', 'E2E: para reabrir.');
    await dev.assume(id);
    await dev.resolve(id);

    await startApp(tester);
    await login(tester, userEmail, userPassword);
    await waitFor(tester, find.byKey(Key('ticket-card-$id')));
    await tester.tap(find.byKey(Key('ticket-card-$id')));
    await waitFor(tester, find.byKey(const Key('reopen-ticket')));
    await tester.tap(find.byKey(const Key('reopen-ticket')));

    await waitFor(tester, _bubble('Ticket reaberto pelo usuário'));
    expect(find.text('Em atendimento'), findsOneWidget);
    expect(find.byKey(const Key('resolution-card')), findsNothing);
    expect((await user.ticket(id))['status'], 'EM_ATENDIMENTO');
  });

  testWidgets('notifications: the bell counts and opens the ticket', (
    tester,
  ) async {
    await dev.setPresence('ONLINE');
    final id = await user.openTicket('DEFEITO_APP', 'E2E: para o sino.');
    await dev.assume(id);
    await user.markAllRead();

    await startApp(tester);
    await login(tester, userEmail, userPassword);
    await waitFor(tester, find.byKey(Key('ticket-card-$id')));

    await dev.sendMessage(id, 'Resposta para o sino.');
    await waitUntil(
      tester,
      () => textOf(tester, const Key('unread-count')) == '1',
      timeout: const Duration(seconds: 45),
      description: 'sino com 1',
    );

    await tester.tap(find.byKey(const Key('bell')));
    final item = find.textContaining('respondeu no ticket #$id.');
    await waitFor(tester, item);
    await tester.tap(item);

    await waitUntil(
      tester,
      () => textOf(tester, const Key('ticket-title')) == '#$id',
      description: 'detalhe do ticket #$id',
    );
    await waitFor(tester, _bubble('Resposta para o sino.'));
    expect(await user.unreadNotifications(), isEmpty);
  });
}
