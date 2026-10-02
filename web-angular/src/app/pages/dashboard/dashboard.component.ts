import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { RouterLink } from '@angular/router';

import {
  DashboardResponse,
  RecentOccurrence
} from '../../core/models/dashboard.model';
import { DashboardService } from '../../core/services/dashboard.service';
import { OmnichannelOverviewComponent } from './omnichannel-overview/omnichannel-overview.component';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterLink, OmnichannelOverviewComponent],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss'
})
export class DashboardComponent implements OnInit {
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
