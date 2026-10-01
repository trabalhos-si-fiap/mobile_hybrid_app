import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/attachments/file_opener.dart';
import 'package:mobile_flutter/core/widgets/attachment_tile.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';
import '../../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final pdf = testAttachment(
    id: 4,
    fileName: 'nota.pdf',
    contentType: 'application/pdf',
    sizeBytes: 2048,
  );

  testWidgets('an image is downloaded once and opens full screen', (
    tester,
  ) async {
    final tickets = FakeTicketRepository();
    final services = testServices(tickets: tickets);
    await pumpScreen(
      tester,
      services,
      Scaffold(body: AttachmentTile(attachment: testAttachment())),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(AttachmentTile));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('tela.png'), findsOneWidget);
    expect(tickets.calls, ['download /tickets/7/attachments/3']);
  });

  testWidgets('a PDF shows name and size and opens in the device app', (
    tester,
  ) async {
    final opener = FakeFileOpener();
    final services = testServices(opener: opener);
    await pumpScreen(
      tester,
      services,
      Scaffold(body: AttachmentTile(attachment: pdf)),
    );

    expect(find.text('nota.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    await tester.tap(find.text('nota.pdf'));
    await tester.pump();

    expect(opener.opened, ['nota.pdf']);
  });

  testWidgets('a PDF without an app to open it shows the reason', (
    tester,
  ) async {
    final opener = FakeFileOpener()
      ..error = const OpenFileException('Nenhum app instalado abre PDF.');
    await pumpScreen(
      tester,
      testServices(opener: opener),
      Scaffold(body: AttachmentTile(attachment: pdf)),
    );

    await tester.tap(find.text('nota.pdf'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nenhum app instalado abre PDF.'), findsOneWidget);
  });

  testWidgets('a failed download shows the API message', (tester) async {
    final tickets = FakeTicketRepository()
      ..downloadError = const ApiException(ApiErrorKind.network);
    await pumpScreen(
      tester,
      testServices(tickets: tickets),
      Scaffold(body: AttachmentTile(attachment: pdf)),
    );

    await tester.tap(find.text('nota.pdf'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
  });
}
