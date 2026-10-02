import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tickets/domain/new_ticket_prefill.dart';

void main() {
  test('NewTicketPrefill compares by value', () {
    const prefill = NewTicketPrefill(
      conversationId: 42,
      segment: 'DEFEITO_APP',
      description: 'O app fecha sozinho.',
    );

    expect(
      prefill,
      const NewTicketPrefill(
        conversationId: 42,
        segment: 'DEFEITO_APP',
        description: 'O app fecha sozinho.',
      ),
    );
    expect(
      prefill,
      isNot(
        const NewTicketPrefill(
          conversationId: 42,
          segment: null,
          description: 'O app fecha sozinho.',
        ),
      ),
    );
  });
}
