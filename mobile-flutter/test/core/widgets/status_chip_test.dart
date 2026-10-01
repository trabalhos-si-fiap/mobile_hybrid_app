import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/widgets/status_chip.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

void main() {
  testWidgets('shows the user-facing label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            StatusChip(status: TicketStatus.escalado),
            StatusChip(status: TicketStatus.resolvido),
          ],
        ),
      ),
    );

    expect(find.text('Prioridade elevada'), findsOneWidget);
    expect(find.text('Resolvido: confirme'), findsOneWidget);
    expect(find.byKey(const Key('status-chip')), findsNWidgets(2));
  });
}
