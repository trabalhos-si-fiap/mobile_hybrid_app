import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app.dart';
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
