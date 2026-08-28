import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';

import { Carrier } from '../../core/models/carrier.model';
import {
  CarrierOccurrence,
  OccurrencePage,
  OccurrenceStatus,
  OccurrenceType
} from '../../core/models/occurrence.model';
import { CarrierService } from '../../core/services/carrier.service';
import { OccurrenceService } from '../../core/services/occurrence.service';
import { OccurrenceDetailModalComponent } from '../../shared/occurrence-detail-modal/occurrence-detail-modal.component';

@Component({
  selector: 'app-occurrences',
  standalone: true,
  imports: [CommonModule, OccurrenceDetailModalComponent],
  templateUrl: './occurrences.component.html',
  styleUrl: './occurrences.component.scss'
})
export class OccurrencesComponent implements OnInit {
  private readonly occurrenceService = inject(OccurrenceService);
  private readonly carrierService = inject(CarrierService);
  private readonly cdr = inject(ChangeDetectorRef);

  pageData: OccurrencePage | null = null;
  carriers: Carrier[] = [];
  selectedOccurrence: CarrierOccurrence | null = null;

  page = 0;
  readonly pageSize = 3;

  carrierId: number | null = null;
  type: OccurrenceType | '' = '';
  status: OccurrenceStatus | '' = '';

  loading = true;

  ngOnInit(): void {
    this.carrierService.getAllCarriers().subscribe(carriers => {
      this.carriers = carriers;
      this.cdr.markForCheck();
    });

    this.loadPage();
  }

  loadPage(): void {
    this.loading = true;

    this.occurrenceService
      .listOccurrences(
        this.page,
        this.pageSize,
        this.carrierId,
        this.type,
        this.status
      )
      .subscribe({
        next: page => {
          this.pageData = page;
          this.loading = false;
          this.cdr.markForCheck();
        },
        error: () => {
          this.loading = false;
          this.cdr.markForCheck();
        }
      });
  }

  carrierChanged(event: Event): void {
    const value = (event.target as HTMLSelectElement).value;
    this.carrierId = value ? Number(value) : null;
    this.resetAndLoad();
  }

  typeChanged(event: Event): void {
    this.type = (event.target as HTMLSelectElement)
      .value as OccurrenceType | '';
    this.resetAndLoad();
  }

  statusChanged(event: Event): void {
    this.status = (event.target as HTMLSelectElement)
      .value as OccurrenceStatus | '';
    this.resetAndLoad();
  }

  resetAndLoad(): void {
    this.page = 0;
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

  typeLabel(type: OccurrenceType): string {
    switch (type) {
      case 'DAMAGE':
        return 'Dano';
      case 'DELIVERY_DELAY':
        return 'Atraso';
      case 'DELIVERY_FAILURE':
        return 'Falha na entrega';
      default:
        return 'Outro';
    }
  }

  typeClass(type: OccurrenceType): string {
    switch (type) {
      case 'DAMAGE':
        return 'damage';
      case 'DELIVERY_FAILURE':
        return 'failure';
      case 'DELIVERY_DELAY':
        return 'delay';
      default:
        return 'other';
    }
  }

  statusLabel(status: OccurrenceStatus): string {
    return status === 'OPEN' ? 'OPEN' : 'RESOLVED';
  }

  formatDate(value: string): string {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;

    const month = new Intl.DateTimeFormat('pt-BR', {
      month: 'short'
    }).format(date).replace('.', '');

    return `${String(date.getDate()).padStart(2, '0')} ${month.charAt(0).toUpperCase() + month.slice(1)}\n${date.getFullYear()}`;
  }

  occurrenceUpdated(): void {
    this.selectedOccurrence = null;
    this.loadPage();
  }
}
