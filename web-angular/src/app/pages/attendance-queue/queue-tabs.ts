import { QueueScope, TicketStatus } from '../../core/models/ticket.model';

export type QueueTab = 'minha' | 'skills' | 'todos';

export interface QueueTabConfig {
  label: string;
  scope: QueueScope;
  /** Status aceitos pelo filtro; espelham o que a API devolve em cada scope. */
  statuses: TicketStatus[];
  emptyMessage: string;
}

export const QUEUE_TABS: Record<QueueTab, QueueTabConfig> = {
  minha: {
    label: 'Minha fila',
    scope: 'mine',
    statuses: ['EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO', 'RESOLVIDO'],
    emptyMessage: 'Nenhum ticket na sua fila.'
  },
  skills: {
    label: 'Filas das minhas skills',
    scope: 'skills',
    statuses: ['EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO'],
    emptyMessage: 'Nenhum ticket nas filas das suas skills.'
  },
  todos: {
    label: 'Todos',
    scope: 'all',
    statuses: ['ABERTO', 'EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO', 'RESOLVIDO'],
    emptyMessage: 'Nenhum ticket aberto.'
  }
};

export interface QueueView {
  tab: QueueTab;
  status: TicketStatus | null;
}

export function visibleTabs(hasEmployee: boolean, isAdmin: boolean): QueueTab[] {
  const tabs: QueueTab[] = hasEmployee ? ['minha', 'skills'] : [];
  return isAdmin ? [...tabs, 'todos'] : tabs;
}

/** Aba e status vindos da URL; um valor que não vale cai na primeira aba e em "todos os status". */
export function resolveQueueView(
  aba: string | null,
  status: string | null,
  tabs: QueueTab[]
): QueueView | null {
  if (tabs.length === 0) {
    return null;
  }

  const tab = tabs.includes(aba as QueueTab) ? (aba as QueueTab) : tabs[0];
  const accepted = QUEUE_TABS[tab].statuses;

  return {
    tab,
    status: accepted.includes(status as TicketStatus) ? (status as TicketStatus) : null
  };
}

export function sameQueueView(a: QueueView | null, b: QueueView | null): boolean {
  return a === b || (!!a && !!b && a.tab === b.tab && a.status === b.status);
}
