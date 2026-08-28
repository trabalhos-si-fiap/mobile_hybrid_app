import { CommonModule } from '@angular/common';
import {
  ChangeDetectorRef,
  Component,
  OnInit,
  inject
} from '@angular/core';
import { forkJoin } from 'rxjs';

import {
  Carrier,
  CarrierPage,
  CarrierStatus,
  CarrierSummary
} from '../../core/models/carrier.model';
import { CarrierService } from '../../core/services/carrier.service';
import { DashboardService } from '../../core/services/dashboard.service';
import { NewCarrierModalComponent } from '../../shared/new-carrier-modal/new-carrier-modal.component';
import { SuccessToastComponent } from '../../shared/success-toast/success-toast.component';

@Component({
  selector: 'app-carriers',
  standalone: true,
  imports: [
    CommonModule,
    NewCarrierModalComponent,
    SuccessToastComponent
  ],
  templateUrl: './carriers.component.html',
  styleUrl: './carriers.component.scss'
})
export class CarriersComponent implements OnInit {
  private readonly carrierService = inject(CarrierService);
  private readonly dashboardService = inject(DashboardService);
  private readonly cdr = inject(ChangeDetectorRef);

  pageData: CarrierPage | null = null;
  summary: CarrierSummary = { total: 0, active: 0, inactive: 0 };
  openOccurrences = 0;

  page = 0;
  readonly pageSize = 3;
  statusFilter: CarrierStatus | '' = '';

  loading = true;
  showCarrierModal = false;
  selectedCarrier: Carrier | null = null;
  showFilters = false;

  successMessage = '';
  private successTimer: number | null = null;

  ngOnInit(): void {
    this.reloadEverything();
  }

  reloadEverything(): void {
    this.loadPage();

    forkJoin({
      summary: this.carrierService.getSummary(),
      dashboard: this.dashboardService.getDashboard(30)
    }).subscribe({
      next: result => {
        this.summary = result.summary;
        this.openOccurrences =
          result.dashboard.operational.openOccurrences;
        this.cdr.markForCheck();
      }
    });
  }

  loadPage(): void {
    this.loading = true;

    this.carrierService
      .listCarriers(
        this.page,
        this.pageSize,
        '',
        this.statusFilter
      )
      .subscribe({
        next: data => {
          this.pageData = data;
          this.loading = false;
          this.cdr.markForCheck();
        },
        error: () => {
          this.loading = false;
          this.cdr.markForCheck();
        }
      });
  }

  openNewCarrier(): void {
    this.selectedCarrier = null;
    this.showCarrierModal = true;
  }

  openEditCarrier(carrier: Carrier): void {
    this.selectedCarrier = carrier;
    this.showCarrierModal = true;
  }

  closeCarrierModal(): void {
    this.showCarrierModal = false;
    this.selectedCarrier = null;
  }

  carrierSaved(mode: 'created' | 'updated'): void {
    this.closeCarrierModal();
    this.page = 0;
    this.reloadEverything();

    this.showSuccess(
      mode === 'created'
        ? 'Transportadora adicionada com sucesso'
        : 'Transportadora editada com sucesso'
    );
  }

  applyStatusFilter(value: string): void {
    this.statusFilter = value as CarrierStatus | '';
    this.page = 0;
    this.showFilters = false;
    this.loadPage();
  }

  previous(): void {
    if (this.page <= 0) return;
    this.page--;
    this.loadPage();
  }

  next(): void {
    if (!this.hasNext) return;
    this.page++;
    this.loadPage();
  }

  get hasNext(): boolean {
    return this.page + 1 < (this.pageData?.totalPages ?? 0);
  }

  get startResult(): number {
    const total = this.pageData?.totalElements ?? 0;
    return total === 0 ? 0 : this.page * this.pageSize + 1;
  }

  get endResult(): number {
    return Math.min(
      (this.page + 1) * this.pageSize,
      this.pageData?.totalElements ?? 0
    );
  }

  statusLabel(status: CarrierStatus): string {
    return status === 'ACTIVE' ? 'Ativa' : 'Inativa';
  }

  initials(name: string): string {
    return name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map(part => part.charAt(0))
      .join('')
      .toUpperCase();
  }

  exportCsv(): void {
    this.carrierService.getAllCarriers().subscribe(carriers => {
      const rows = [
        [
          'Nome',
          'Status',
          'Localidade',
          'E-mail',
          'Prazo médio',
          'Avaliação',
          'SLA'
        ],
        ...carriers.map(carrier => [
          carrier.name,
          carrier.status,
          carrier.location,
          carrier.email,
          String(carrier.averageDeliveryDays),
          String(carrier.rating),
          String(carrier.slaPercentage)
        ])
      ];

      const csv = rows
        .map(row =>
          row
            .map(value => `"${String(value).replaceAll('"', '""')}"`)
            .join(';')
        )
        .join('\n');

      const blob = new Blob([`\uFEFF${csv}`], {
        type: 'text/csv;charset=utf-8'
      });

      const url = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = 'transportadoras.csv';
      anchor.click();
      URL.revokeObjectURL(url);
      this.cdr.markForCheck();
    });
  }

  private showSuccess(message: string): void {
    this.successMessage = message;

    if (this.successTimer !== null) {
      window.clearTimeout(this.successTimer);
    }

    this.successTimer = window.setTimeout(() => {
      this.successMessage = '';
      this.successTimer = null;
      this.cdr.markForCheck();
    }, 3200);

    this.cdr.markForCheck();
  }
}
