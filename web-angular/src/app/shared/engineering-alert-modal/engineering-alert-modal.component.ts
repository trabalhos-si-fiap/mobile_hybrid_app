import { Component, inject, input, output, signal } from '@angular/core';

import { TicketDetail } from '../../core/models/ticket.model';
import { TicketService } from '../../core/services/ticket.service';
import {
  apiErrorMessage,
  GENERIC_ACTION_ERROR,
  httpStatus,
  isTransientError,
} from '../../core/utils/api-error';
import { ModalDirective } from '../modal/modal.directive';

/** Mesmo limite do EngineeringAlertRequest da API. */
export const ALERT_REASON_MAX = 500;

@Component({
  selector: 'app-engineering-alert-modal',
  standalone: true,
  imports: [ModalDirective],
  templateUrl: './engineering-alert-modal.component.html',
})
export class EngineeringAlertModalComponent {
  private readonly tickets = inject(TicketService);

  readonly ticket = input.required<TicketDetail>();

  readonly closed = output<void>();
  readonly raised = output<TicketDetail>();
  /** 409, 404, 403: o console mostra o aviso e recarrega. */
  readonly failed = output<unknown>();

  readonly reason = signal('');
  readonly saving = signal(false);
  readonly error = signal('');
  readonly maxLength = ALERT_REASON_MAX;

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

    const text = this.reason().trim();
    if (!text) {
      this.error.set('Descreva o motivo do alerta.');
      return;
    }
    if (text.length > ALERT_REASON_MAX) {
      this.error.set(`O motivo passa de ${ALERT_REASON_MAX} caracteres.`);
      return;
    }

    this.saving.set(true);
    this.error.set('');

    this.tickets.raiseEngineeringAlert(this.ticket().id, text).subscribe({
      next: (ticket) => {
        this.saving.set(false);
        this.raised.emit(ticket);
      },
      error: (error) => {
        this.saving.set(false);
        if (httpStatus(error) === 400) {
          this.error.set(apiErrorMessage(error, 'Confira o motivo do alerta.'));
        } else if (isTransientError(error)) {
          this.error.set(GENERIC_ACTION_ERROR);
        } else {
          this.failed.emit(error);
        }
      },
    });
  }
}
