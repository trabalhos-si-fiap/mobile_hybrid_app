export type Segment = 'DEFEITO_APP' | 'PROBLEMA_PEDIDO' | 'FEEDBACK_SUGESTAO';

export type TicketStatus =
  | 'ABERTO'
  | 'EM_FILA'
  | 'EM_ATENDIMENTO'
  | 'ESCALADO'
  | 'RESOLVIDO'
  | 'FECHADO';

export type TicketPriority = 'NORMAL' | 'ALTA' | 'CRITICA';

export type SlaStatus = 'NO_PRAZO' | 'EM_RISCO' | 'ESTOURADO' | 'CUMPRIDO' | 'VIOLADO';

export type Presence = 'ONLINE' | 'AUSENTE' | 'OFFLINE';

export type TicketQueue = 'TECNOLOGIA' | 'MARKETPLACE' | 'PRODUTO';

export type TicketChannel = 'APP' | 'CHATBOT_IA';

export type SenderType = 'USER' | 'EMPLOYEE' | 'SYSTEM';

export type TicketEventType =
  | 'ABERTO'
  | 'ROTEADO'
  | 'ASSUMIDO'
  | 'TRANSFERIDO'
  | 'ESCALADO'
  | 'RESOLVIDO'
  | 'REABERTO'
  | 'FECHADO'
  | 'ALERTA_ENGENHARIA'
  | 'ERRO_ESCALONAMENTO';

export type NotificationType =
  | 'TICKET_ATRIBUIDO'
  | 'TICKET_ASSUMIDO'
  | 'NOVA_MENSAGEM'
  | 'TICKET_RESOLVIDO'
  | 'TICKET_ESCALADO'
  | 'ALERTA_ENGENHARIA'
  | 'TICKET_FECHADO';

export type QueueScope = 'mine' | 'skills' | 'all';

export interface SegmentOption {
  segment: Segment;
  label: string;
  queue: TicketQueue;
  skill: string;
  slaMinutes: number;
}

export interface UserSummary {
  id: number;
  name: string;
  email: string;
}

export interface EmployeeSummary {
  id: number;
  name: string;
}

export interface Attachment {
  id: number;
  fileName: string;
  contentType: string;
  sizeBytes: number;
  /** Relativo à base da API, ex. /tickets/7/attachments/3. */
  downloadPath: string;
}

export interface TicketSummary {
  id: number;
  segment: Segment;
  segmentLabel: string;
  status: TicketStatus;
  priority: TicketPriority;
  slaStatus: SlaStatus;
  slaDueAt: string | null;
  requesterName: string;
  assigneeName: string | null;
  engineeringAlert: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface TicketDetail {
  id: number;
  segment: Segment;
  segmentLabel: string;
  queue: TicketQueue;
  status: TicketStatus;
  priority: TicketPriority;
  channel: TicketChannel;
  description: string;
  slaStatus: SlaStatus;
  slaDueAt: string | null;
  requester: UserSummary;
  assignee: EmployeeSummary | null;
  engineeringAlert: boolean;
  engineeringAlertReason: string | null;
  attachments: Attachment[];
  createdAt: string;
  updatedAt: string;
  assumedAt: string | null;
  resolvedAt: string | null;
  closedAt: string | null;
}

export interface TicketMessage {
  id: number;
  senderType: SenderType;
  senderName: string;
  body: string;
  attachments: Attachment[];
  createdAt: string;
}

export interface TicketEvent {
  id: number;
  type: TicketEventType;
  fromStatus: TicketStatus | null;
  toStatus: TicketStatus | null;
  employeeName: string | null;
  detail: string | null;
  createdAt: string;
}

export interface EmployeeMe {
  id: number;
  name: string;
  presence: Presence;
  presenceChangedAt: string;
  skills: string[];
}

export interface AppNotification {
  id: number;
  ticketId: number | null;
  type: NotificationType;
  title: string;
  body: string;
  read: boolean;
  createdAt: string;
}

export interface ApiErrorResponse {
  timestamp?: string;
  status?: number;
  error?: string;
  message?: string;
  path?: string;
}
