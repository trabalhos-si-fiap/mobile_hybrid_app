import { describe, expect, it } from 'vitest';

import { TicketDetail } from '../models/ticket.model';
import {
  ADMIN,
  aSummary,
  aTicket,
  NO_EMPLOYEE,
  OTHER_AGENT,
  OWNER,
  REQUESTER_STAFF
} from '../../testing/test-data';
import {
  availableActions,
  canAssumeFromQueue,
  chatBlockReason,
  TicketAction,
  Viewer
} from './ticket-permissions';

describe('availableActions', () => {
  const cases: Array<[string, Partial<TicketDetail>, Viewer, TicketAction[]]> = [
    ['EM_FILA sem dono, atendente', { status: 'EM_FILA', assignee: null }, OTHER_AGENT, ['assume']],
    ['EM_FILA meu', { status: 'EM_FILA' }, OWNER, ['assume', 'transfer', 'engineeringAlert']],
    ['EM_FILA de outro', { status: 'EM_FILA' }, OTHER_AGENT, []],
    ['EM_FILA de outro, ADMIN', { status: 'EM_FILA' }, ADMIN, ['assume', 'transfer', 'engineeringAlert']],
    ['ESCALADO sem dono, atendente', { status: 'ESCALADO', assignee: null }, OTHER_AGENT, ['assume']],
    ['ESCALADO meu', { status: 'ESCALADO' }, OWNER, ['assume', 'transfer', 'engineeringAlert']],
    ['EM_ATENDIMENTO meu', {}, OWNER, ['resolve', 'transfer', 'engineeringAlert']],
    ['EM_ATENDIMENTO de outro', {}, OTHER_AGENT, []],
    ['EM_ATENDIMENTO de outro, ADMIN', {}, ADMIN, ['resolve', 'transfer', 'engineeringAlert']],
    ['EM_ATENDIMENTO meu, já alertado', { engineeringAlert: true }, OWNER, ['resolve', 'transfer']],
    ['ABERTO, ADMIN', { status: 'ABERTO', assignee: null }, ADMIN, ['engineeringAlert']],
    ['ABERTO, atendente', { status: 'ABERTO', assignee: null }, OTHER_AGENT, []],
    ['RESOLVIDO meu', { status: 'RESOLVIDO' }, OWNER, ['engineeringAlert']],
    ['FECHADO meu', { status: 'FECHADO' }, OWNER, []],
    ['FECHADO, ADMIN', { status: 'FECHADO' }, ADMIN, []],
    ['solicitante staff, na fila', { status: 'EM_FILA', assignee: null }, REQUESTER_STAFF, []],
    ['solicitante staff e dono', { assignee: { id: 10, name: 'Rita' } }, REQUESTER_STAFF, []],
    ['sem cadastro de atendente', { status: 'EM_FILA', assignee: null }, NO_EMPLOYEE, []],
    ['ADMIN sem cadastro', { status: 'EM_FILA', assignee: null }, { ...NO_EMPLOYEE, isAdmin: true }, []]
  ];

  it.each(cases)('%s', (_name, overrides, viewer, expected) => {
    expect(availableActions(aTicket(overrides), viewer)).toEqual(expected);
  });
});

describe('chatBlockReason', () => {
  it('blocks staff without an agent record first', () => {
    expect(chatBlockReason(aTicket(), NO_EMPLOYEE)).toBe(
      'Sua conta não está cadastrada como atendente.'
    );
    expect(chatBlockReason(aTicket(), { ...NO_EMPLOYEE, userId: 50 })).toBe(
      'Sua conta não está cadastrada como atendente.'
    );
  });

  it('sends the requester to the app', () => {
    expect(chatBlockReason(aTicket(), REQUESTER_STAFF)).toBe(
      'Você abriu este ticket. Responda pelo app Edu.'
    );
  });

  it('explains closed and resolved tickets', () => {
    expect(chatBlockReason(aTicket({ status: 'FECHADO' }), OWNER)).toBe('Ticket fechado.');
    expect(chatBlockReason(aTicket({ status: 'RESOLVIDO' }), OWNER)).toBe(
      'Ticket resolvido. Aguardando a confirmação do usuário.'
    );
  });

  it.each(['ABERTO', 'EM_FILA', 'ESCALADO'] as const)('asks to assume a %s ticket', status => {
    expect(chatBlockReason(aTicket({ status }), OWNER)).toBe('Assuma o ticket para responder.');
  });

  it('names the agent of a ticket in service with someone else', () => {
    expect(chatBlockReason(aTicket(), OTHER_AGENT)).toBe('Ticket em atendimento por Diego Dev.');
  });

  it('lets the owner and ADMIN reply', () => {
    expect(chatBlockReason(aTicket(), OWNER)).toBeNull();
    expect(chatBlockReason(aTicket(), ADMIN)).toBeNull();
  });
});

describe('canAssumeFromQueue', () => {
  it('offers Atender for waiting tickets in my queue', () => {
    expect(canAssumeFromQueue(aSummary({ status: 'EM_FILA' }), true, OWNER)).toBe(true);
    expect(canAssumeFromQueue(aSummary({ status: 'ESCALADO' }), true, OWNER)).toBe(true);
  });

  it('offers Atender for unassigned tickets in other tabs', () => {
    expect(canAssumeFromQueue(aSummary({ assigneeName: null }), false, OTHER_AGENT)).toBe(true);
  });

  it('only offers Abrir for a ticket assigned to someone else, unless ADMIN', () => {
    expect(canAssumeFromQueue(aSummary(), false, OTHER_AGENT)).toBe(false);
    expect(canAssumeFromQueue(aSummary(), false, ADMIN)).toBe(true);
  });

  it('never offers Atender outside EM_FILA and ESCALADO', () => {
    expect(canAssumeFromQueue(aSummary({ status: 'EM_ATENDIMENTO' }), true, OWNER)).toBe(false);
    expect(canAssumeFromQueue(aSummary({ status: 'RESOLVIDO' }), true, OWNER)).toBe(false);
  });

  it('never offers Atender without an agent record', () => {
    expect(
      canAssumeFromQueue(aSummary({ assigneeName: null }), false, { ...NO_EMPLOYEE, isAdmin: true })
    ).toBe(false);
  });
});
