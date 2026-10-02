import { describe, expect, it } from 'vitest';

import { badgeClass, CHANNEL_LABELS, isSlaRunning, STATUS_LABELS } from './ticket-labels';

describe('ticket-labels', () => {
  it('builds the badge class from kind and value', () => {
    expect(badgeClass('status', 'EM_ATENDIMENTO')).toBe('badge badge-status-em-atendimento');
    expect(badgeClass('sla', 'NO_PRAZO')).toBe('badge badge-sla-no-prazo');
  });

  it('labels every status in Portuguese', () => {
    expect(STATUS_LABELS.EM_FILA).toBe('Em fila');
    expect(STATUS_LABELS.RESOLVIDO).toBe('Resolvido');
  });

  it('labels the bot channel as "Chatbot", without IA', () => {
    expect(CHANNEL_LABELS.APP).toBe('App');
    expect(CHANNEL_LABELS.CHATBOT_IA).toBe('Chatbot');
  });

  it('knows when the SLA clock is still running', () => {
    expect(isSlaRunning('NO_PRAZO')).toBe(true);
    expect(isSlaRunning('ESTOURADO')).toBe(true);
    expect(isSlaRunning('CUMPRIDO')).toBe(false);
    expect(isSlaRunning('VIOLADO')).toBe(false);
  });
});
