import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/core/widgets/attachment_source.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';
import '../../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('the buttons report the chosen source', (tester) async {
    final picked = <AttachmentSource>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AttachmentSourceButtons(onPick: picked.add)),
      ),
    );

    await tester.tap(find.byKey(const Key('attach-camera')));
    await tester.tap(find.byKey(const Key('attach-gallery')));
    await tester.tap(find.byKey(const Key('attach-pdf')));

    expect(picked, [
      AttachmentSource.camera,
      AttachmentSource.gallery,
      AttachmentSource.pdf,
    ]);
  });

  testWidgets('disabled buttons do nothing', (tester) async {
    final picked = <AttachmentSource>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentSourceButtons(onPick: picked.add, enabled: false),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('attach-pdf')));
    expect(picked, isEmpty);
  });

  testWidgets('the sheet returns the chosen source', (tester) async {
    AttachmentSource? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                chosen = await showAttachmentSourceSheet(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach-gallery')));
    await tester.pumpAndSettle();

    expect(chosen, AttachmentSource.gallery);
  });

  testWidgets('pickAttachments shows the picker error', (tester) async {
    final picker = FakeAttachmentPicker()
      ..error = const AttachmentPickException(
        'Permita o acesso à câmera nas configurações do aparelho.',
      );
    List<PickedAttachment>? result = [pickedPng()];
    await pumpScreen(
      tester,
      testServices(picker: picker),
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await pickAttachments(
              context,
              AttachmentSource.camera,
              limit: 5,
            ),
            child: const Text('anexar'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('anexar'));
    await tester.pump();
    await tester.pump();

    expect(result, isNull);
    expect(
      find.text('Permita o acesso à câmera nas configurações do aparelho.'),
      findsOneWidget,
    );
    expect(picker.requests.single.limit, 5);
  });
}
