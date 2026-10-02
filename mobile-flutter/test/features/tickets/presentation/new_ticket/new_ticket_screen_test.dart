import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/tickets/domain/new_ticket_prefill.dart';
import 'package:mobile_flutter/features/tickets/presentation/new_ticket/new_ticket_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/harness.dart';
import '../../../../support/test_data.dart';

void main() {
  late FakeTicketRepository tickets;
  late FakeAttachmentPicker picker;
  late AppServices services;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tickets = FakeTicketRepository();
    picker = FakeAttachmentPicker();
    services = testServices(tickets: tickets, picker: picker);
  });

  const notice = 'Sua conversa com o Mentor Edu vai junto com o ticket.';
  const prefill = NewTicketPrefill(
    conversationId: 42,
    segment: 'PROBLEMA_PEDIDO',
    description: 'O pedido veio sem um item.',
  );

  Future<void> pump(WidgetTester tester, {NewTicketPrefill? prefill}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, services, NewTicketScreen(prefill: prefill));
  }

  bool selected(String segment) => find
      .descendant(
        of: find.byKey(Key('segment-$segment')),
        matching: find.byIcon(Icons.radio_button_checked),
      )
      .evaluate()
      .isNotEmpty;

  String description(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('description-input')))
      .controller!
      .text;

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('submit-ticket')));
    await tester.tap(find.byKey(const Key('submit-ticket')));
    await tester.pump();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('segment-DEFEITO_APP')));
    await tester.enterText(
      find.byKey(const Key('description-input')),
      'O app fecha sozinho.',
    );
    await tester.pump();
  }

  int openCalls() => tickets.calls.where((c) => c.startsWith('open')).length;

  testWidgets('shows the segments with their deadlines', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('segment-DEFEITO_APP')), findsOneWidget);
    expect(find.text('Defeito no App'), findsOneWidget);
    expect(find.text('Prazo de atendimento: 4 h'), findsOneWidget);
    expect(find.text('Prazo de atendimento: 8 h'), findsOneWidget);
    expect(find.text('Prazo de atendimento: 2 dias'), findsOneWidget);
  });

  testWidgets('asks for a segment and a description', (tester) async {
    await pump(tester);

    await tapSubmit(tester);
    expect(find.text('Escolha o tipo do problema.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('segment-FEEDBACK_SUGESTAO')));
    await tester.enterText(find.byKey(const Key('description-input')), '   ');
    await tapSubmit(tester);
    expect(find.text('Descreva o problema.'), findsOneWidget);
    expect(openCalls(), 0);
  });

  testWidgets('adds valid attachments, refuses the others, and removes', (
    tester,
  ) async {
    picker.next = [
      pickedPng(),
      PickedAttachment(name: 'foto.heic', bytes: Uint8List(3)),
    ];
    await pump(tester);

    await tester.tap(find.byKey(const Key('attach-gallery')));
    await tester.pump();

    expect(picker.requests.single.source, AttachmentSource.gallery);
    expect(picker.requests.single.limit, 5);
    expect(find.text('tela.png'), findsOneWidget);
    expect(
      find.text('foto.heic: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byTooltip('Remover tela.png'));
    await tester.tap(find.byTooltip('Remover tela.png'));
    await tester.pump();
    expect(find.text('tela.png'), findsNothing);
  });

  testWidgets('disables the attachment buttons at five files', (tester) async {
    picker.next = [for (var i = 1; i <= 5; i++) pickedPng(name: '$i.png')];
    await pump(tester);

    await tester.tap(find.byKey(const Key('attach-camera')));
    await tester.pump();

    final pdf = tester.widget<OutlinedButton>(
      find.byKey(const Key('attach-pdf')),
    );
    expect(pdf.onPressed, isNull);
  });

  testWidgets('sends and replaces itself with the ticket', (tester) async {
    picker.next = [pickedPdf()];
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('attach-pdf')));
    await tester.pump();

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(tickets.calls, contains('open DEFEITO_APP'));
    expect(tickets.sentBodies, ['O app fecha sozinho.']);
    expect(tickets.sentFiles.single.single.name, 'nota.pdf');
    expect(tickets.openedConversations, [null]);
    expect(find.text('route:/tickets/12'), findsOneWidget);
  });

  testWidgets('without a prefill there is no notice and nothing selected', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(notice), findsNothing);
    expect(selected('DEFEITO_APP'), isFalse);
    expect(selected('PROBLEMA_PEDIDO'), isFalse);
    expect(description(tester), isEmpty);
  });

  testWidgets('a prefill marks the segment, fills the description and shows '
      'the notice', (tester) async {
    await pump(tester, prefill: prefill);

    expect(find.text(notice), findsOneWidget);
    expect(selected('PROBLEMA_PEDIDO'), isTrue);
    expect(selected('DEFEITO_APP'), isFalse);
    expect(description(tester), 'O pedido veio sem um item.');
  });

  testWidgets('the prefilled fields stay editable', (tester) async {
    await pump(tester, prefill: prefill);

    await tester.tap(find.byKey(const Key('segment-DEFEITO_APP')));
    await tester.enterText(
      find.byKey(const Key('description-input')),
      'Na verdade o app fecha sozinho.',
    );
    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(tickets.calls, contains('open DEFEITO_APP'));
    expect(tickets.sentBodies, ['Na verdade o app fecha sozinho.']);
    expect(tickets.openedConversations, [42]);
  });

  testWidgets('sends the conversation id with the ticket', (tester) async {
    await pump(tester, prefill: prefill);

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(tickets.calls, contains('open PROBLEMA_PEDIDO'));
    expect(tickets.sentBodies, ['O pedido veio sem um item.']);
    expect(tickets.openedConversations, [42]);
    expect(find.text('route:/tickets/12'), findsOneWidget);
  });

  testWidgets('a prefill without a segment leaves the choice to the user', (
    tester,
  ) async {
    await pump(
      tester,
      prefill: const NewTicketPrefill(
        conversationId: 42,
        segment: null,
        description: '',
      ),
    );

    expect(find.text(notice), findsOneWidget);
    expect(selected('DEFEITO_APP'), isFalse);

    await tapSubmit(tester);
    expect(find.text('Escolha o tipo do problema.'), findsOneWidget);
    expect(openCalls(), 0);
  });

  testWidgets('a 409 lets go of the conversation and the next send opens '
      'without it', (tester) async {
    tickets.actionError = const ApiException(ApiErrorKind.conflict);
    await pump(tester, prefill: prefill);

    await tapSubmit(tester);
    await tester.pump();

    expect(
      find.text(
        'Não foi possível ligar a conversa. Envie de novo para abrir o '
        'ticket sem ela.',
      ),
      findsOneWidget,
    );
    expect(find.text(notice), findsNothing);
    expect(selected('PROBLEMA_PEDIDO'), isTrue);
    expect(description(tester), 'O pedido veio sem um item.');
    expect(find.textContaining('route:'), findsNothing);

    tickets.actionError = null;
    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(tickets.openedConversations, [42, null]);
    expect(find.text('route:/tickets/12'), findsOneWidget);
  });

  testWidgets('a 409 without a conversation keeps the usual message', (
    tester,
  ) async {
    tickets.actionError = const ApiException(ApiErrorKind.conflict);
    await pump(tester);
    await fill(tester);

    await tapSubmit(tester);
    await tester.pump();

    expect(
      find.text('O ticket mudou de situação. A tela foi atualizada.'),
      findsOneWidget,
    );
  });

  testWidgets('an error keeps what was typed and attached', (tester) async {
    tickets.actionError = const ApiException(
      ApiErrorKind.badRequest,
      serverMessage: 'Anexo inválido.',
    );
    picker.next = [pickedPng()];
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('attach-gallery')));
    await tester.pump();

    await tapSubmit(tester);
    await tester.pump();

    expect(find.text('Anexo inválido.'), findsOneWidget);
    expect(find.text('O app fecha sozinho.'), findsOneWidget);
    expect(find.text('tela.png'), findsOneWidget);
    expect(find.textContaining('route:'), findsNothing);
  });

  testWidgets('a 422 reloads the segments', (tester) async {
    tickets.actionError = const ApiException(
      ApiErrorKind.unprocessable,
      serverMessage: 'Segmento sem configuração ativa.',
    );
    await pump(tester);
    await fill(tester);

    await tapSubmit(tester);
    await tester.pump();

    expect(find.text('Segmento sem configuração ativa.'), findsOneWidget);
    expect(tickets.calls.where((c) => c == 'segments'), hasLength(2));
  });

  testWidgets('submits only once on a double tap', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);
    await fill(tester);

    await tester.ensureVisible(find.byKey(const Key('submit-ticket')));
    await tester.tap(find.byKey(const Key('submit-ticket')));
    await tester.tap(find.byKey(const Key('submit-ticket')));
    await tester.pump();
    tickets.gate!.complete();
    await tester.pumpAndSettle();

    expect(openCalls(), 1);
  });

  testWidgets('leaving during submit does not throw', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);
    await fill(tester);
    await tapSubmit(tester);

    await tester.pumpWidget(const SizedBox());
    tickets.gate!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
