import { Component, computed, inject, input, output, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import { Segment, SegmentOption, TicketDetail } from '../../core/models/ticket.model';
import { TicketService } from '../../core/services/ticket.service';
import {
  apiErrorMessage,
  GENERIC_ACTION_ERROR,
  httpStatus,
  isTransientError,
} from '../../core/utils/api-error';

export interface TransferResult {
  ticket: TicketDetail;
  label: string;
}

@Component({
  selector: 'app-transfer-modal',
  standalone: true,
  templateUrl: './transfer-modal.component.html',
})
export class TransferModalComponent {
  private readonly tickets = inject(TicketService);

  readonly ticket = input.required<TicketDetail>();

  readonly closed = output<void>();
  readonly transferred = output<TransferResult>();
  /** 409, 404, 403: o console mostra o aviso e recarrega. */
  readonly failed = output<unknown>();

  readonly segments = signal<SegmentOption[] | null>(null);
  readonly selected = signal('');
  readonly saving = signal(false);
  readonly error = signal('');
  readonly options = computed(() =>
    (this.segments() ?? []).filter((option) => option.segment !== this.ticket().segment),
  );

  constructor() {
    this.tickets
      .segments()
      .pipe(takeUntilDestroyed())
      .subscribe({
        next: (segments) => this.segments.set(segments),
        error: () => {
          this.segments.set([]);
          this.error.set('Não foi possível carregar os segmentos.');
        },
      });
  }

  close(): void {
    if (!this.saving()) {
      this.closed.emit();
    }
  }

  onBackdropMouseDown(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.close();
    }
  }

  submit(): void {
    if (this.saving()) {
      return;
    }

    const option = this.options().find((item) => item.segment === this.selected());
    if (!option) {
      this.error.set('Escolha o segmento de destino.');
      return;
    }

    this.saving.set(true);
    this.error.set('');

    this.tickets.transfer(this.ticket().id, option.segment as Segment).subscribe({
      next: (ticket) => {
        this.saving.set(false);
        this.transferred.emit({ ticket, label: option.label });
      },
      error: (error) => {
        this.saving.set(false);
        const status = httpStatus(error);
        if (status === 400 || status === 422) {
          this.error.set(apiErrorMessage(error, 'Não foi possível transferir.'));
        } else if (isTransientError(error)) {
          this.error.set(GENERIC_ACTION_ERROR);
        } else {
          this.failed.emit(error);
        }
      },
    });
  }
}
