import '../../../core/utils/time_format.dart';
import 'ticket_models.dart';

/// Rótulos e regras de tela do ponto de vista do usuário. A API continua
/// sendo a autoridade: uma ação fora de hora volta 409.
enum StatusTone { waiting, priority, active, resolved, closed }

String statusLabel(TicketStatus status) => switch (status) {
  TicketStatus.aberto || TicketStatus.emFila => 'Aguardando atendente',
  TicketStatus.escalado => 'Prioridade elevada',
  TicketStatus.emAtendimento => 'Em atendimento',
  TicketStatus.resolvido => 'Resolvido: confirme',
  TicketStatus.fechado => 'Fechado',
};

StatusTone statusTone(TicketStatus status) => switch (status) {
  TicketStatus.aberto || TicketStatus.emFila => StatusTone.waiting,
  TicketStatus.escalado => StatusTone.priority,
  TicketStatus.emAtendimento => StatusTone.active,
  TicketStatus.resolvido => StatusTone.resolved,
  TicketStatus.fechado => StatusTone.closed,
};

bool canAnswerResolution(TicketStatus status) =>
    status == TicketStatus.resolvido;

bool canSendMessage(TicketStatus status) => status != TicketStatus.fechado;

bool isSlaRunning(SlaStatus sla) =>
    sla == SlaStatus.noPrazo ||
    sla == SlaStatus.emRisco ||
    sla == SlaStatus.estourado;

String assigneeText(String? assigneeName) =>
    assigneeName == null ? 'Aguardando atendente' : 'Atendente: $assigneeName';

/// "Prazo: até 30/09 14:00"; nulo quando o prazo já não corre.
String? deadlineText(SlaStatus sla, DateTime? dueAt) {
  if (dueAt == null || !isSlaRunning(sla)) return null;
  final text = 'Prazo: até ${formatDateTime(dueAt)}';
  return sla == SlaStatus.estourado ? '$text (vencido)' : text;
}

String segmentDeadlineText(int slaMinutes) =>
    'Prazo de atendimento: ${_duration(slaMinutes)}';

String _duration(int minutes) {
  const minutesPerDay = 24 * 60;
  if (minutes >= minutesPerDay && minutes % minutesPerDay == 0) {
    final days = minutes ~/ minutesPerDay;
    return days == 1 ? '1 dia' : '$days dias';
  }
  if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60} h';
  return '$minutes min';
}

/// Os resolvidos (esperando a resposta do usuário) primeiro; o resto na
/// ordem da API, mais recentes primeiro.
List<TicketSummary> sortForUser(List<TicketSummary> tickets) => [
  ...tickets.where((ticket) => ticket.status == TicketStatus.resolvido),
  ...tickets.where((ticket) => ticket.status != TicketStatus.resolvido),
];
