import { describe, expect, it } from 'vitest';

import { QUEUE_TABS, resolveQueueView, sameQueueView, visibleTabs } from './queue-tabs';

describe('queue-tabs', () => {
  it('mirrors the scope and the accepted statuses of the API', () => {
    expect(QUEUE_TABS.minha.scope).toBe('mine');
    expect(QUEUE_TABS.minha.statuses).toEqual([
      'EM_FILA',
      'EM_ATENDIMENTO',
      'ESCALADO',
      'RESOLVIDO',
    ]);
    expect(QUEUE_TABS.skills.scope).toBe('skills');
    expect(QUEUE_TABS.skills.statuses).toEqual(['EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO']);
    expect(QUEUE_TABS.todos.scope).toBe('all');
    expect(QUEUE_TABS.todos.statuses).toEqual([
      'ABERTO',
      'EM_FILA',
      'EM_ATENDIMENTO',
      'ESCALADO',
      'RESOLVIDO',
    ]);
  });

  it('shows the tabs each profile can use', () => {
    expect(visibleTabs(true, false)).toEqual(['minha', 'skills']);
    expect(visibleTabs(true, true)).toEqual(['minha', 'skills', 'todos']);
    expect(visibleTabs(false, true)).toEqual(['todos']);
    expect(visibleTabs(false, false)).toEqual([]);
  });

  it('reads the tab and the status from the URL', () => {
    expect(resolveQueueView('skills', 'EM_FILA', ['minha', 'skills'])).toEqual({
      tab: 'skills',
      status: 'EM_FILA',
    });
  });

  it('falls back to the first tab and drops statuses the tab does not accept', () => {
    expect(resolveQueueView('todos', null, ['minha', 'skills'])).toEqual({
      tab: 'minha',
      status: null,
    });
    expect(resolveQueueView(null, 'ABERTO', ['minha', 'skills'])).toEqual({
      tab: 'minha',
      status: null,
    });
    expect(resolveQueueView('minha', 'FECHADO', ['minha'])).toEqual({ tab: 'minha', status: null });
  });

  it('has no view without tabs', () => {
    expect(resolveQueueView('minha', null, [])).toBeNull();
  });

  it('compares views by value', () => {
    expect(sameQueueView({ tab: 'minha', status: null }, { tab: 'minha', status: null })).toBe(
      true,
    );
    expect(sameQueueView({ tab: 'minha', status: null }, { tab: 'minha', status: 'EM_FILA' })).toBe(
      false,
    );
    expect(sameQueueView(null, null)).toBe(true);
    expect(sameQueueView(null, { tab: 'minha', status: null })).toBe(false);
  });
});
