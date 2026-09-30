import { describe, expect, it } from 'vitest';

import { NOW } from '../../testing/test-data';
import { formatDateTime, formatTime, relativeTime, slaDueLabel } from './time-format';

describe('time-format', () => {
  it('formats an absolute date as dd/mm/aaaa hh:mm in the given time zone', () => {
    expect(formatDateTime('2026-09-29T15:04:00Z', 'America/Sao_Paulo')).toBe('29/09/2026 12:04');
    expect(formatDateTime('2026-09-29T03:00:00Z', 'America/Sao_Paulo')).toBe('29/09/2026 00:00');
  });

  it('shows a dash for a missing or broken date', () => {
    expect(formatDateTime(null)).toBe('—');
    expect(formatDateTime('não é data')).toBe('—');
  });

  it('formats the time of a chat message', () => {
    expect(formatTime('2026-09-29T15:04:00Z', 'America/Sao_Paulo')).toBe('12:04');
  });

  it('tells past and future times relative to a fixed clock', () => {
    expect(relativeTime('2026-09-29T11:59:30Z', NOW)).toBe('agora');
    expect(relativeTime('2026-09-29T11:59:00Z', NOW)).toBe('há 1 minuto');
    expect(relativeTime('2026-09-29T11:50:00Z', NOW)).toBe('há 10 minutos');
    expect(relativeTime('2026-09-29T14:00:00Z', NOW)).toBe('em 2 horas');
    expect(relativeTime('2026-09-29T09:10:00Z', NOW)).toBe('há 2 horas');
    expect(relativeTime('2026-09-26T12:00:00Z', NOW)).toBe('há 3 dias');
    expect(relativeTime('2026-09-30T13:00:00Z', NOW)).toBe('em 1 dia');
  });

  it('labels the SLA deadline', () => {
    expect(slaDueLabel('2026-09-29T14:00:00Z', NOW)).toBe('vence em 2 horas');
    expect(slaDueLabel('2026-09-29T11:50:00Z', NOW)).toBe('venceu há 10 minutos');
    expect(slaDueLabel('2026-09-29T12:00:20Z', NOW)).toBe('vence agora');
    expect(slaDueLabel(null, NOW)).toBe('sem prazo');
  });
});
