import { Segment } from './ticket.model';

export type DashboardPeriod = 7 | 30 | 90;

/** Valor no período, no anterior e a variação percentual; todos podem faltar. */
export interface MetricComparison {
  current: number | null;
  previous: number | null;
  variation: number | null;
}

export interface OmnichannelKpis {
  opened: MetricComparison;
  resolved: MetricComparison;
  backlog: number;
  slaMetPercentage: MetricComparison;
  escalated: MetricComparison;
  averageMinutesToAssume: MetricComparison;
  averageHoursToResolve: MetricComparison;
  openedByChannel: { app: MetricComparison; chatbot: MetricComparison };
}

export interface SegmentSummary {
  segment: Segment;
  label: string;
  opened: MetricComparison;
  resolved: MetricComparison;
  slaMetPercentage: MetricComparison;
  backlog: number;
}

export type AnomalyStatus = 'NORMAL' | 'ANOMALIA' | 'SEM_HISTORICO';
export type AnomalyDirection = 'PICO' | 'QUEDA';

export interface SegmentAnomaly {
  segment: Segment;
  label: string;
  last24h: number;
  mean: number | null;
  standardDeviation: number | null;
  zScore: number | null;
  status: AnomalyStatus;
  direction: AnomalyDirection | null;
  windows: number;
}

export interface OmnichannelDashboard {
  days: DashboardPeriod;
  periodStart: string;
  periodEnd: string;
  kpis: OmnichannelKpis;
  segments: SegmentSummary[];
  anomalies: SegmentAnomaly[];
  highlights: string[];
}
