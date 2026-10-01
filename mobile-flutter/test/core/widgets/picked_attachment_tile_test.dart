import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/widgets/picked_attachment_tile.dart';

import '../../support/test_data.dart';

void main() {
  testWidgets('shows name and size and removes', (tester) async {
    var removed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickedAttachmentTile(
            file: pickedPdf(),
            onRemove: () => removed++,
          ),
        ),
      ),
    );

    expect(find.text('nota.pdf'), findsOneWidget);
    expect(find.text('${pdfBytes.length} B'), findsOneWidget);
    await tester.tap(find.byTooltip('Remover nota.pdf'));
    expect(removed, 1);
  });
}
