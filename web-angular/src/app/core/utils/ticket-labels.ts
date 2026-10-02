import {
  Presence,
  SlaStatus,
  TicketChannel,
  TicketEventType,
  TicketPriority,
  TicketQueue,
  TicketStatus,
} from '../models/ticket.model';

export const STATUS_LABELS: Record<TicketStatus, string> = {
  ABERTO: 'Aberto',
  EM_FILA: 'Em fila',
  EM_ATENDIMENTO: 'Em atendimento',
  ESCALADO: 'Escalado',
  RESOLVIDO: 'Resolvido',
  FECHADO: 'Fechado',
};

export const PRIORITY_LABELS: Record<TicketPriority, string> = {
  NORMAL: 'Normal',
  ALTA: 'Alta',
  CRITICA: 'Crítica',
};

export const SLA_LABELS: Record<SlaStatus, string> = {
  NO_PRAZO: 'No prazo',
  EM_RISCO: 'Em risco',
  ESTOURADO: 'Estourado',
  CUMPRIDO: 'Cumprido',
  VIOLADO: 'Violado',
};

export const PRESENCE_LABELS: Record<Presence, string> = {
  ONLINE: 'Online',
  AUSENTE: 'Ausente',
  OFFLINE: 'Offline',
};

export const CHANNEL_LABELS: Record<TicketChannel, string> = {
  APP: 'App',
  CHATBOT_IA: 'Chatbot',
};

export const QUEUE_LABELS: Record<TicketQueue, string> = {
  TECNOLOGIA: 'Tecnologia',
  MARKETPLACE: 'Marketplace',
  PRODUTO: 'Produto',
};

export const EVENT_LABELS: Record<TicketEventType, string> = {
  ABERTO: 'Aberto',
  ROTEADO: 'Roteado',
  ASSUMIDO: 'Assumido',
  TRANSFERIDO: 'Transferido',
  ESCALADO: 'Escalado',
  RESOLVIDO: 'Resolvido',
  REABERTO: 'Reaberto',
  FECHADO: 'Fechado',
  ALERTA_ENGENHARIA: 'Alerta de engenharia',
  ERRO_ESCALONAMENTO: 'Erro no escalonamento',
};

export type BadgeKind = 'status' | 'priority' | 'sla';

/** Classes globais de src/styles/_badges.scss, ex. "badge badge-status-em-fila". */
export function badgeClass(kind: BadgeKind, value: string): string {
  return `badge badge-${kind}-${value.toLowerCase().replaceAll('_', '-')}`;
}

/** CUMPRIDO e VIOLADO são finais: o prazo já não corre. */
export function isSlaRunning(sla: SlaStatus): boolean {
  return sla === 'NO_PRAZO' || sla === 'EM_RISCO' || sla === 'ESTOURADO';
}
