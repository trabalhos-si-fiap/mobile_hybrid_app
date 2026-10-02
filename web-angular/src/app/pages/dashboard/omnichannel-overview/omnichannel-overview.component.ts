import { Component, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { catchError, of, Subject, switchMap, tap } from 'rxjs';

import {
  DashboardPeriod,
  MetricComparison,
  OmnichannelDashboard,
} from '../../../core/models/omnichannel-dashboard.model';
import { OmnichannelDashboardService } from '../../../core/services/omnichannel-dashboard.service';
import { anomalyChip, formatNumber, VariationBadge, variationBadge } from './omnichannel-format';

interface KpiCard {
  key: string;
  label: string;
  value: string;
  badge: VariationBadge | null;
}

@Component({
  selector: 'app-omnichannel-overview',
  standalone: true,
  templateUrl: './omnichannel-overview.component.html',
  styleUrl: './omnichannel-overview.component.scss',
})
export class OmnichannelOverviewComponent {
  private readonly dashboards = inject(OmnichannelDashboardService);
  private readonly requests = new Subject<DashboardPeriod>();

  readonly periods: readonly DashboardPeriod[] = [7, 30, 90];
  readonly period = signal<DashboardPeriod>(7);
  readonly data = signal<OmnichannelDashboard | null>(null);
  readonly loading = signal(true);
  readonly failed = signal(false);

  readonly cards = computed<KpiCard[]>(() => {
    const kpis = this.data()?.kpis;
    if (!kpis) {
      return [];
    }
    return [
      card('opened', 'Abertos', kpis.opened, false),
      card('resolved', 'Resolvidos', kpis.resolved, true),
      { key: 'backlog', label: 'Backlog', value: formatNumber(kpis.backlog), badge: null },
      card('sla', 'SLA cumprido', kpis.slaMetPercentage, true, '%'),
      card('escalated', 'Escalados', kpis.escalated, false),
      card('assume', 'Tempo até assumir', kpis.averageMinutesToAssume, false, ' min'),
      card('resolve', 'Tempo de resolução', kpis.averageHoursToResolve, false, ' h'),
    ];
  });

  readonly channels = computed(() => {
    const byChannel = this.data()?.kpis.openedByChannel;
    if (!byChannel) {
      return [];
    }
    return [
      card('app', 'App', byChannel.app, false),
      card('chatbot', 'Chatbot', byChannel.chatbot, false),
    ];
  });

  readonly anomalies = computed(() =>
    (this.data()?.anomalies ?? []).map((anomaly) => {
      const chip = anomalyChip(anomaly);
      return {
        segment: anomaly.segment,
        label: anomaly.label,
        summary: `${formatNumber(anomaly.last24h)} tickets · média ${formatNumber(anomaly.mean, 2)}`,
        chip: chip.key,
        chipLabel: chip.label,
      };
    }),
  );

  readonly segments = computed(() =>
    (this.data()?.segments ?? []).map((row) => ({
      segment: row.segment,
      label: row.label,
      cells: [
        card('opened', 'Abertos', row.opened, false),
        card('resolved', 'Resolvidos', row.resolved, true),
        card('sla', 'SLA cumprido', row.slaMetPercentage, true, '%'),
      ],
      backlog: formatNumber(row.backlog),
    })),
  );

  constructor() {
    // switchMap: trocar de período cancela a busca anterior, e uma resposta
    // atrasada nunca sobrescreve a do período escolhido.
    this.requests
      .pipe(
        tap(() => {
          this.loading.set(true);
          this.failed.set(false);
        }),
        switchMap((days) =>
          this.dashboards.get(days).pipe(catchError(() => of<OmnichannelDashboard | null>(null))),
        ),
        takeUntilDestroyed(),
      )
      .subscribe((data) => {
        this.loading.set(false);
        this.data.set(data);
        this.failed.set(data === null);
      });
    this.requests.next(this.period());
  }

  choose(days: DashboardPeriod): void {
    if (days === this.period() && this.data() !== null) {
      return;
    }
    this.period.set(days);
    this.requests.next(days);
  }

  retry(): void {
    this.requests.next(this.period());
  }
}

function card(
  key: string,
  label: string,
  metric: MetricComparison,
  higherIsBetter: boolean,
  suffix = '',
): KpiCard {
  return {
    key,
    label,
    value: metric.current === null ? '—' : `${formatNumber(metric.current)}${suffix}`,
    badge: variationBadge(metric.variation, higherIsBetter),
  };
}
