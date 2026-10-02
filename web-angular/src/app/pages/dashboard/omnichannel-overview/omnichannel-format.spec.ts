import { describe, expect, it } from 'vitest';

import { anOverview } from '../../../testing/dashboard-data';
import { anomalyChip, formatNumber, variationBadge } from './omnichannel-format';

describe('omnichannel format', () => {
  it('formats numbers in pt-BR with a dash for missing values', () => {
    expect(formatNumber(29.2)).toBe('29,2');
    expect(formatNumber(1234)).toBe('1.234');
    expect(formatNumber(3.456, 2)).toBe('3,46');
    expect(formatNumber(0)).toBe('0');
    expect(formatNumber(null)).toBe('—');
  });

  it('paints a change red when it goes the wrong way and green when it goes the right way', () => {
    expect(variationBadge(29.2, false)).toEqual({ text: '▲ 29,2%', tone: 'bad' });
    expect(variationBadge(8, true)).toEqual({ text: '▲ 8%', tone: 'good' });
    expect(variationBadge(-3.4, true)).toEqual({ text: '▼ 3,4%', tone: 'bad' });
    expect(variationBadge(-19.4, false)).toEqual({ text: '▼ 19,4%', tone: 'good' });
  });

  it('shows no change as neutral and a missing base as such', () => {
    expect(variationBadge(0, true)).toEqual({ text: '0%', tone: 'neutral' });
    expect(variationBadge(null, false)).toEqual({ text: '— sem base', tone: 'none' });
  });

  it('gives each anomaly its chip', () => {
    const [defect, order, feedback] = anOverview().anomalies;

    expect(anomalyChip(defect)).toEqual({ key: 'NORMAL', label: 'Normal' });
    expect(anomalyChip(order)).toEqual({ key: 'PICO', label: 'Pico' });
    expect(anomalyChip(feedback)).toEqual({ key: 'SEM_HISTORICO', label: 'Sem histórico' });
    expect(anomalyChip({ ...defect, status: 'ANOMALIA', direction: 'QUEDA' })).toEqual({
      key: 'QUEDA',
      label: 'Queda',
    });
  });
});
