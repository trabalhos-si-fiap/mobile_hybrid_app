import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/utils/time_format.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_rules.dart';

TicketSummary _summary(int id, TicketStatus status) => TicketSummary(
  id: id,
  segmentLabel: 'Defeito no App',
  status: status,
  slaStatus: SlaStatus.noPrazo,
  slaDueAt: null,
  assigneeName: null,
  createdAt: DateTime.utc(2026, 9, 30, 13),
  updatedAt: DateTime.utc(2026, 9, 30, 13),
);

void main() {
  test('status labels and tones for the user', () {
    const expected = {
      TicketStatus.aberto: ('Aguardando atendente', StatusTone.waiting),
      TicketStatus.emFila: ('Aguardando atendente', StatusTone.waiting),
      TicketStatus.escalado: ('Prioridade elevada', StatusTone.priority),
      TicketStatus.emAtendimento: ('Em atendimento', StatusTone.active),
      TicketStatus.resolvido: ('Resolvido: confirme', StatusTone.resolved),
      TicketStatus.fechado: ('Fechado', StatusTone.closed),
    };
    for (final status in TicketStatus.values) {
      expect(statusLabel(status), expected[status]!.$1, reason: '$status');
      expect(statusTone(status), expected[status]!.$2, reason: '$status');
    }
  });

  test('only RESOLVIDO asks the user to confirm or reopen', () {
    for (final status in TicketStatus.values) {
      expect(
        canAnswerResolution(status),
        status == TicketStatus.resolvido,
        reason: '$status',
      );
    }
  });

  test('messages are blocked only when FECHADO', () {
    for (final status in TicketStatus.values) {
      expect(
        canSendMessage(status),
        status != TicketStatus.fechado,
        reason: '$status',
      );
    }
  });

  test('the SLA runs only while the ticket is open', () {
    expect(isSlaRunning(SlaStatus.noPrazo), isTrue);
    expect(isSlaRunning(SlaStatus.emRisco), isTrue);
    expect(isSlaRunning(SlaStatus.estourado), isTrue);
    expect(isSlaRunning(SlaStatus.cumprido), isFalse);
    expect(isSlaRunning(SlaStatus.violado), isFalse);
  });

  test('assigneeText', () {
    expect(assigneeText(null), 'Aguardando atendente');
    expect(assigneeText('Dev'), 'Atendente: Dev');
  });

  group('deadlineText', () {
    final due = DateTime.utc(2026, 9, 30, 17);

    test('shows the deadline while it runs', () {
      expect(
        deadlineText(SlaStatus.noPrazo, due),
        'Prazo: até ${formatDateTime(due)}',
      );
      expect(
        deadlineText(SlaStatus.emRisco, due),
        'Prazo: até ${formatDateTime(due)}',
      );
    });

    test('marks an overdue deadline', () {
      expect(
        deadlineText(SlaStatus.estourado, due),
        'Prazo: até ${formatDateTime(due)} (vencido)',
      );
    });

    test('hides it when the SLA is final or there is no date', () {
      expect(deadlineText(SlaStatus.cumprido, due), isNull);
      expect(deadlineText(SlaStatus.violado, due), isNull);
      expect(deadlineText(SlaStatus.noPrazo, null), isNull);
    });
  });

  test('segmentDeadlineText uses days, hours or minutes', () {
    expect(segmentDeadlineText(240), 'Prazo de atendimento: 4 h');
    expect(segmentDeadlineText(480), 'Prazo de atendimento: 8 h');
    expect(segmentDeadlineText(1440), 'Prazo de atendimento: 1 dia');
    expect(segmentDeadlineText(2880), 'Prazo de atendimento: 2 dias');
    expect(segmentDeadlineText(90), 'Prazo de atendimento: 90 min');
  });

  test('sortForUser puts RESOLVIDO first and keeps the API order', () {
    final sorted = sortForUser([
      _summary(9, TicketStatus.emAtendimento),
      _summary(8, TicketStatus.resolvido),
      _summary(7, TicketStatus.fechado),
      _summary(6, TicketStatus.resolvido),
    ]);
    expect(sorted.map((ticket) => ticket.id), [8, 6, 9, 7]);
  });
}
