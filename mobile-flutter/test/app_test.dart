import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app.dart';
import 'package:mobile_flutter/features/tickets/domain/new_ticket_prefill.dart';
import 'package:mobile_flutter/features/tickets/presentation/new_ticket/new_ticket_screen.dart';
import 'package:mobile_flutter/features/tickets/presentation/ticket_detail/ticket_detail_screen.dart';

void main() {
  test('/tickets/<id> opens the ticket detail', () {
    final route = EduApp.onGenerateRoute(
      const RouteSettings(name: '/tickets/7'),
    );

    expect(route, isA<MaterialPageRoute<void>>());
    final page = (route! as MaterialPageRoute<void>).builder(_FakeContext());
    expect(page, isA<TicketDetailScreen>());
    expect((page as TicketDetailScreen).ticketId, 7);
  });

  test('/tickets/new opens the form with the prefill in the arguments', () {
    const prefill = NewTicketPrefill(
      conversationId: 42,
      segment: 'DEFEITO_APP',
      description: 'O app fecha sozinho.',
    );
    NewTicketScreen screenFor(RouteSettings settings) =>
        (EduApp.onGenerateRoute(settings)! as MaterialPageRoute<void>).builder(
              _FakeContext(),
            )
            as NewTicketScreen;

    expect(
      screenFor(
        const RouteSettings(name: '/tickets/new', arguments: prefill),
      ).prefill,
      prefill,
    );
    expect(
      screenFor(const RouteSettings(name: '/tickets/new')).prefill,
      isNull,
    );
  });

  test('other unknown routes are not handled', () {
    expect(
      EduApp.onGenerateRoute(const RouteSettings(name: '/tickets/abc')),
      isNull,
    );
    expect(
      EduApp.onGenerateRoute(const RouteSettings(name: '/tickets/7/x')),
      isNull,
    );
    expect(EduApp.onGenerateRoute(const RouteSettings(name: '/nada')), isNull);
  });
}

class _FakeContext extends Fake implements BuildContext {}
