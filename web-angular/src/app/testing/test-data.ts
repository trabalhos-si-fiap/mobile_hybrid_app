import { HttpErrorResponse } from '@angular/common/http';

import {
  AppNotification,
  Attachment,
  EmployeeMe,
  SegmentOption,
  TicketDetail,
  TicketMessage,
  TicketSummary
} from '../core/models/ticket.model';
import { Viewer } from '../core/utils/ticket-permissions';

/** Relógio fixo dos testes: 29/09/2026 12:00 UTC. */
export const NOW = Date.parse('2026-09-29T12:00:00Z');

/** Ticket #12, EM_ATENDIMENTO com o atendente 7 (Diego Dev); solicitante é o usuário 50. */
export function aTicket(overrides: Partial<TicketDetail> = {}): TicketDetail {
  return {
    id: 12,
    segment: 'DEFEITO_APP',
    segmentLabel: 'Defeito no App / Problemas com App',
    queue: 'TECNOLOGIA',
    status: 'EM_ATENDIMENTO',
    priority: 'ALTA',
    channel: 'APP',
    description: 'O app fecha ao abrir o carrinho.',
    slaStatus: 'NO_PRAZO',
    slaDueAt: '2026-09-29T14:00:00Z',
    requester: { id: 50, name: 'Ana Usuária', email: 'ana@edu.com' },
    assignee: { id: 7, name: 'Diego Dev' },
    engineeringAlert: false,
    engineeringAlertReason: null,
    attachments: [],
    createdAt: '2026-09-29T10:00:00Z',
    updatedAt: '2026-09-29T11:00:00Z',
    assumedAt: '2026-09-29T10:30:00Z',
    resolvedAt: null,
    closedAt: null,
    ...overrides
  };
}

export function aSummary(overrides: Partial<TicketSummary> = {}): TicketSummary {
  return {
    id: 12,
    segment: 'DEFEITO_APP',
    segmentLabel: 'Defeito no App / Problemas com App',
    status: 'EM_FILA',
    priority: 'ALTA',
    slaStatus: 'NO_PRAZO',
    slaDueAt: '2026-09-29T14:00:00Z',
    requesterName: 'Ana Usuária',
    assigneeName: 'Diego Dev',
    engineeringAlert: false,
    createdAt: '2026-09-29T10:00:00Z',
    updatedAt: '2026-09-29T11:00:00Z',
    ...overrides
  };
}

export function aMessage(overrides: Partial<TicketMessage> = {}): TicketMessage {
  return {
    id: 100,
    senderType: 'USER',
    senderName: 'Ana Usuária',
    body: 'Oi, o app travou de novo.',
    attachments: [],
    createdAt: '2026-09-29T10:05:00Z',
    ...overrides
  };
}

export function anAttachment(overrides: Partial<Attachment> = {}): Attachment {
  return {
    id: 3,
    fileName: 'print.png',
    contentType: 'image/png',
    sizeBytes: 2048,
    downloadPath: '/tickets/12/attachments/3',
    ...overrides
  };
}

/** Atendente 7 (Diego Dev), usuário 20. */
export function anEmployee(overrides: Partial<EmployeeMe> = {}): EmployeeMe {
  return {
    id: 7,
    name: 'Diego Dev',
    presence: 'ONLINE',
    presenceChangedAt: '2026-09-29T11:30:00Z',
    skills: ['DESENVOLVEDOR'],
    ...overrides
  };
}

export function aNotification(overrides: Partial<AppNotification> = {}): AppNotification {
  return {
    id: 900,
    ticketId: 12,
    type: 'NOVA_MENSAGEM',
    title: 'Nova mensagem',
    body: 'O usuário respondeu no ticket #12.',
    read: false,
    createdAt: '2026-09-29T11:55:00Z',
    ...overrides
  };
}

export const SEGMENTS: SegmentOption[] = [
  {
    segment: 'DEFEITO_APP',
    label: 'Defeito no App / Problemas com App',
    queue: 'TECNOLOGIA',
    skill: 'DESENVOLVEDOR',
    slaMinutes: 240
  },
  {
    segment: 'PROBLEMA_PEDIDO',
    label: 'Problemas com pedido',
    queue: 'MARKETPLACE',
    skill: 'GESTAO_ENTREGAS',
    slaMinutes: 480
  },
  {
    segment: 'FEEDBACK_SUGESTAO',
    label: 'Feedback / Sugestões',
    queue: 'PRODUTO',
    skill: 'PRODUTO_MELHORIAS',
    slaMinutes: 2880
  }
];

/** Erro HTTP no formato do ApiErrorResponse; sem mensagem, o corpo vem nulo. */
export function httpError(status: number, message?: string): HttpErrorResponse {
  return new HttpErrorResponse({
    status,
    statusText: 'Error',
    error: message === undefined ? null : { status, message }
  });
}

/** Arquivo com tamanho declarado, sem alocar o conteúdo. */
export function fakeFile(name: string, type: string, size: number): File {
  const file = new File([], name, { type });
  Object.defineProperty(file, 'size', { value: size });
  return file;
}

/** Diego Dev: usuário 20, atendente 7, dono do aTicket(). */
export const OWNER: Viewer = { userId: 20, isAdmin: false, employeeId: 7 };

/** Rita: usuário 21, atendente 8, mesma skill, não é dona. */
export const OTHER_AGENT: Viewer = { userId: 21, isAdmin: false, employeeId: 8 };

/** ADMIN com cadastro de atendente (9). */
export const ADMIN: Viewer = { userId: 1, isAdmin: true, employeeId: 9 };

/** Staff que abriu o próprio ticket: é o usuário 50, solicitante do aTicket(). */
export const REQUESTER_STAFF: Viewer = { userId: 50, isAdmin: false, employeeId: 10 };

/** Staff sem cadastro de atendente (GET /employees/me respondeu 403). */
export const NO_EMPLOYEE: Viewer = { userId: 30, isAdmin: false, employeeId: null };
