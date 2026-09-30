import { TicketDetail, TicketSummary } from '../models/ticket.model';

/** Quem está olhando a tela. */
export interface Viewer {
  /** AuthUser.id */
  userId: number;
  isAdmin: boolean;
  /** id de GET /employees/me, ou null para staff sem cadastro de atendente. */
  employeeId: number | null;
}

export type TicketAction = 'assume' | 'resolve' | 'transfer' | 'engineeringAlert';

function isRequester(ticket: TicketDetail, viewer: Viewer): boolean {
  return ticket.requester.id === viewer.userId;
}

function isMine(ticket: TicketDetail, viewer: Viewer): boolean {
  return viewer.employeeId !== null && ticket.assignee?.id === viewer.employeeId;
}

function isWaiting(status: TicketDetail['status']): boolean {
  return status === 'EM_FILA' || status === 'ESCALADO';
}

/** Ações rápidas permitidas agora; espelha as regras da 2A (Ticket.java). */
export function availableActions(ticket: TicketDetail, viewer: Viewer): TicketAction[] {
  if (viewer.employeeId === null || isRequester(ticket, viewer)) {
    return [];
  }

  const owns = isMine(ticket, viewer) || viewer.isAdmin;
  const waiting = isWaiting(ticket.status);
  const actions: TicketAction[] = [];

  if (waiting && (ticket.assignee === null || owns)) {
    actions.push('assume');
  }
  if (ticket.status === 'EM_ATENDIMENTO' && owns) {
    actions.push('resolve');
  }
  if ((waiting || ticket.status === 'EM_ATENDIMENTO') && owns) {
    actions.push('transfer');
  }
  if (ticket.status !== 'FECHADO' && !ticket.engineeringAlert && owns) {
    actions.push('engineeringAlert');
  }
  return actions;
}

/** Motivo do chat bloqueado (primeira regra que valer), ou null quando dá para responder. */
export function chatBlockReason(ticket: TicketDetail, viewer: Viewer): string | null {
  if (viewer.employeeId === null) {
    return 'Sua conta não está cadastrada como atendente.';
  }
  if (isRequester(ticket, viewer)) {
    return 'Você abriu este ticket. Responda pelo app Edu.';
  }

  switch (ticket.status) {
    case 'FECHADO':
      return 'Ticket fechado.';
    case 'RESOLVIDO':
      return 'Ticket resolvido. Aguardando a confirmação do usuário.';
    case 'ABERTO':
    case 'EM_FILA':
    case 'ESCALADO':
      return 'Assuma o ticket para responder.';
  }

  if (!isMine(ticket, viewer) && !viewer.isAdmin) {
    return `Ticket em atendimento por ${ticket.assignee?.name ?? 'outro atendente'}.`;
  }
  return null;
}

/**
 * Regra aproximada do botão Atender na fila: o resumo não traz o id do atendente.
 * O console decide com o detalhe completo, e a API recusa com 409 qualquer caso errado.
 */
export function canAssumeFromQueue(row: TicketSummary, inMyQueue: boolean, viewer: Viewer): boolean {
  if (viewer.employeeId === null) {
    return false;
  }
  const waiting = row.status === 'EM_FILA' || row.status === 'ESCALADO';
  return waiting && (inMyQueue || row.assigneeName === null || viewer.isAdmin);
}
