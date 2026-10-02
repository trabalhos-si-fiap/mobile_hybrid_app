import { SegmentAnomaly } from '../../../core/models/omnichannel-dashboard.model';

const formats = new Map<number, Intl.NumberFormat>();

/** Número em pt-BR com até `digits` casas decimais; "—" quando não há valor. */
export function formatNumber(value: number | null, digits = 1): string {
  if (value === null) {
    return '—';
  }
  let format = formats.get(digits);
  if (!format) {
    format = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: digits });
    formats.set(digits, format);
  }
  return format.format(value);
}

export type BadgeTone = 'good' | 'bad' | 'neutral' | 'none';

export interface VariationBadge {
  text: string;
  tone: BadgeTone;
}

/**
 * Selo da variação. A cor segue o sentido bom da métrica: subir é bom em
 * resolvidos e SLA, ruim em abertos, escalados e tempos.
 */
export function variationBadge(variation: number | null, higherIsBetter: boolean): VariationBadge {
  if (variation === null) {
    return { text: '— sem base', tone: 'none' };
  }
  if (variation === 0) {
    return { text: '0%', tone: 'neutral' };
  }
  const rising = variation > 0;
  const good = rising === higherIsBetter;
  return {
    text: `${rising ? '▲' : '▼'} ${formatNumber(Math.abs(variation))}%`,
    tone: good ? 'good' : 'bad',
  };
}

export type AnomalyChipKey = 'PICO' | 'QUEDA' | 'NORMAL' | 'SEM_HISTORICO';

const CHIP_LABELS: Record<AnomalyChipKey, string> = {
  PICO: 'Pico',
  QUEDA: 'Queda',
  NORMAL: 'Normal',
  SEM_HISTORICO: 'Sem histórico',
};

export function anomalyChip(anomaly: SegmentAnomaly): { key: AnomalyChipKey; label: string } {
  const key: AnomalyChipKey =
    anomaly.direction ?? (anomaly.status === 'SEM_HISTORICO' ? 'SEM_HISTORICO' : 'NORMAL');
  return { key, label: CHIP_LABELS[key] };
}
