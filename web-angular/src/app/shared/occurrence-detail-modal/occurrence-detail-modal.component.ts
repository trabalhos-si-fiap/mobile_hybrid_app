import { CommonModule } from '@angular/common';
import {
  ChangeDetectorRef,
  Component,
  EventEmitter,
  Input,
  Output,
  inject
} from '@angular/core';

import {
  CarrierOccurrence,
  OccurrenceStatus,
  OccurrenceType
} from '../../core/models/occurrence.model';
import { OccurrenceService } from '../../core/services/occurrence.service';

@Component({
  selector: 'app-occurrence-detail-modal',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './occurrence-detail-modal.component.html',
  styleUrl: './occurrence-detail-modal.component.scss'
})
export class OccurrenceDetailModalComponent {
  private readonly occurrenceService = inject(OccurrenceService);
  private readonly cdr = inject(ChangeDetectorRef);

  @Input({ required: true }) occurrence!: CarrierOccurrence;

  @Output() closed = new EventEmitter<void>();
  @Output() updated = new EventEmitter<void>();

  saving = false;

  close(): void {
    if (!this.saving) this.closed.emit();
  }

  toggleStatus(): void {
    const nextStatus: OccurrenceStatus =
      this.occurrence.status === 'OPEN' ? 'RESOLVED' : 'OPEN';

    this.saving = true;

    this.occurrenceService
      .updateStatus(this.occurrence.id, nextStatus)
      .subscribe({
        next: () => {
          this.saving = false;
          this.cdr.markForCheck();
          this.updated.emit();
        },
        error: () => {
          this.saving = false;
          this.cdr.markForCheck();
        }
      });
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

  formatDate(value: string): string {
    const date = new Date(value);
    return Number.isNaN(date.getTime())
      ? value
      : new Intl.DateTimeFormat('pt-BR', {
          dateStyle: 'medium',
          timeStyle: 'short'
        }).format(date);
  }

  onBackdrop(event: MouseEvent): void {
    if (event.target === event.currentTarget) this.close();
  }
}
