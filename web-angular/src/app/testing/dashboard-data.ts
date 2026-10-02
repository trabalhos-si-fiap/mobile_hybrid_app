import { DashboardResponse } from '../core/models/dashboard.model';
import {
  MetricComparison,
  OmnichannelDashboard,
  SegmentAnomaly,
} from '../core/models/omnichannel-dashboard.model';
import { Segment } from '../core/models/ticket.model';

const LABELS: Record<Segment, string> = {
  DEFEITO_APP: 'Defeito no App / Problemas com App',
  PROBLEMA_PEDIDO: 'Problemas com pedido',
  FEEDBACK_SUGESTAO: 'Feedback / Sugestões',
};

function metric(
  current: number | null,
  previous: number | null,
  variation: number | null,
): MetricComparison {
  return { current, previous, variation };
}

/** Resumo de 7 dias: pico em Problemas com pedido e Feedback ainda sem histórico. */
export function anOverview(overrides: Partial<OmnichannelDashboard> = {}): OmnichannelDashboard {
  return {
    days: 7,
    periodStart: '2026-09-25T15:00:00Z',
    periodEnd: '2026-10-02T15:00:00Z',
    kpis: {
      opened: metric(31, 24, 29.2),
      resolved: metric(27, 25, 8),
      backlog: 6,
      slaMetPercentage: metric(88.9, 92, -3.4),
      escalated: metric(2, 2, 0),
      averageMinutesToAssume: metric(14.5, 18, -19.4),
      averageHoursToResolve: metric(6.2, null, null),
      openedByChannel: { app: metric(26, 21, 23.8), chatbot: metric(5, 3, 66.7) },
    },
    segments: [
      {
        segment: 'DEFEITO_APP',
        label: LABELS.DEFEITO_APP,
        opened: metric(10, 8, 25),
        resolved: metric(9, 9, 0),
        slaMetPercentage: metric(88.9, 100, -11.1),
        backlog: 2,
      },
      {
        segment: 'PROBLEMA_PEDIDO',
        label: LABELS.PROBLEMA_PEDIDO,
        opened: metric(15, 10, 50),
        resolved: metric(12, 10, 20),
        slaMetPercentage: metric(91.7, 90, 1.9),
        backlog: 3,
      },
      {
        segment: 'FEEDBACK_SUGESTAO',
        label: LABELS.FEEDBACK_SUGESTAO,
        opened: metric(6, 6, 0),
        resolved: metric(6, 6, 0),
        slaMetPercentage: metric(null, null, null),
        backlog: 1,
      },
    ],
    anomalies: [
      anomaly('DEFEITO_APP', 3, 3.5, 'NORMAL', null),
      anomaly('PROBLEMA_PEDIDO', 12, 3.5, 'ANOMALIA', 'PICO'),
      anomaly('FEEDBACK_SUGESTAO', 0, null, 'SEM_HISTORICO', null),
    ],
    highlights: [
      'Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,5.',
    ],
    ...overrides,
  };
}

/** Base nova: nada aberto ainda e nenhum histórico para comparar. */
export function anEmptyOverview(): OmnichannelDashboard {
  const zero = metric(0, 0, null);
  const none = metric(null, null, null);
  const segments: Segment[] = ['DEFEITO_APP', 'PROBLEMA_PEDIDO', 'FEEDBACK_SUGESTAO'];
  return {
    days: 7,
    periodStart: '2026-09-25T15:00:00Z',
    periodEnd: '2026-10-02T15:00:00Z',
    kpis: {
      opened: zero,
      resolved: zero,
      backlog: 0,
      slaMetPercentage: none,
      escalated: zero,
      averageMinutesToAssume: none,
      averageHoursToResolve: none,
      openedByChannel: { app: zero, chatbot: zero },
    },
    segments: segments.map((segment) => ({
      segment,
      label: LABELS[segment],
      opened: zero,
      resolved: zero,
      slaMetPercentage: none,
      backlog: 0,
    })),
    anomalies: segments.map((segment) => anomaly(segment, 0, null, 'SEM_HISTORICO', null)),
    highlights: ['Nenhum alerta no atendimento no período.'],
  };
}

function anomaly(
  segment: Segment,
  last24h: number,
  mean: number | null,
  status: SegmentAnomaly['status'],
  direction: SegmentAnomaly['direction'],
): SegmentAnomaly {
  return {
    segment,
    label: LABELS[segment],
    last24h,
    mean,
    standardDeviation: mean === null ? null : 1.14,
    zScore: mean === null ? null : Math.round(((last24h - mean) / 1.14) * 100) / 100,
    status,
    direction,
    windows: mean === null ? 3 : 28,
  };
}

/** Resposta do GET /dashboard (bloco operacional do dashboard). */
export function aDashboard(): DashboardResponse {
  return {
    educational: {
      registeredStudents: 128,
      activeStudents: 84,
      newRegistrations: 12,
      inactiveRiskStudents: 9,
      activityHistory: [{ date: '2026-10-01', studyActivities: 40, newRegistrations: 3 }],
    },
    operational: {
      registeredProducts: 5,
      lowStockProducts: 4,
      activeCarriers: 4,
      openOccurrences: 2,
      lowStock: [
        {
          productId: 1,
          productName: 'Caderno',
          sku: 'EDU-SEED0001',
          currentQuantity: 2,
          minimumStock: 10,
          status: 'LOW_STOCK',
        },
      ],
      carriers: [
        {
          carrierId: 1,
          name: 'Rápida Log',
          rating: 4.5,
          slaPercentage: 96,
          averageDeliveryDays: 3,
        },
      ],
      recentOccurrences: [
        {
          occurrenceId: 7,
          type: 'DELIVERY_DELAY',
          carrierName: 'Rápida Log',
          createdAt: '2026-10-02T12:00:00Z',
          status: 'OPEN',
        },
      ],
    },
    executiveSummary: '66% dos alunos estão ativos.',
  };
}
