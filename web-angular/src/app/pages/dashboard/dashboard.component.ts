import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { RouterLink } from '@angular/router';

import {
  ActivityHistoryItem,
  DashboardResponse,
  RecentOccurrence
} from '../../core/models/dashboard.model';
import { DashboardService } from '../../core/services/dashboard.service';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss'
})
export class DashboardComponent implements OnInit {
  readonly Math = Math;
  private readonly dashboardService = inject(DashboardService);
  private readonly cdr = inject(ChangeDetectorRef);

  data: DashboardResponse | null = null;
  loading = true;
  errorMessage = '';

  ngOnInit(): void {
    this.dashboardService.getDashboard(30).subscribe({
      next: data => {
        this.data = data;
        this.loading = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.errorMessage = 'Não foi possível carregar o dashboard.';
        this.loading = false;
        this.cdr.markForCheck();
      }
    });
  }

  get history(): ActivityHistoryItem[] {
    return (this.data?.educational.activityHistory ?? []).slice(-7);
  }

  get chartLinePoints(): string {
    if (!this.history.length) return '';

    const values = this.history.map(item => item.studyActivities);
    const max = Math.max(...values, 1);
    const min = Math.min(...values, 0);
    const range = Math.max(max - min, 1);

    return this.history
      .map((item, index) => {
        const x = 38 + index * (474 / Math.max(this.history.length - 1, 1));
        const y = 196 - ((item.studyActivities - min) / range) * 154;
        return `${x},${y}`;
      })
      .join(' ');
  }

  get chartAreaPoints(): string {
    if (!this.chartLinePoints) return '';
    const firstX = 38;
    const lastX = 38 + (this.history.length - 1) * (474 / Math.max(this.history.length - 1, 1));
    return `${firstX},196 ${this.chartLinePoints} ${lastX},196`;
  }

  barX(index: number): number {
    return 25 + index * (486 / Math.max(this.history.length, 1));
  }

  barHeight(value: number): number {
    const max = Math.max(
      ...this.history.map(item => item.newRegistrations),
      1
    );
    return 145 * (value / max);
  }

  historyLabel(item: ActivityHistoryItem): string {
    const date = new Date(`${item.date}T00:00:00`);
    return Number.isNaN(date.getTime())
      ? item.date
      : String(date.getDate());
  }

  occurrenceTypeLabel(type: RecentOccurrence['type']): string {
    switch (type) {
      case 'DELIVERY_DELAY':
        return 'Atraso na Entrega';
      case 'DAMAGE':
        return 'Produto Danificado';
      case 'DELIVERY_FAILURE':
        return 'Falha na Entrega';
      default:
        return 'Outra Ocorrência';
    }
  }

  timeAgo(value: string): string {
    const time = new Date(value).getTime();
    if (Number.isNaN(time)) return '';

    const diffHours = Math.max(
      0,
      Math.floor((Date.now() - time) / 3_600_000)
    );

    if (diffHours < 1) return 'Agora';
    if (diffHours < 24) return `Há ${diffHours}h`;

    return `Há ${Math.floor(diffHours / 24)}d`;
  }
}
