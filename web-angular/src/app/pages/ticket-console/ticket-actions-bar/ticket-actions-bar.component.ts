import { Component, input, output, signal } from '@angular/core';

import { TicketDetail } from '../../../core/models/ticket.model';
import { TicketAction } from '../../../core/utils/ticket-permissions';
import { ConfirmDialogComponent } from '../../../shared/confirm-dialog/confirm-dialog.component';
import { EngineeringAlertModalComponent } from '../../../shared/engineering-alert-modal/engineering-alert-modal.component';
import {
  TransferModalComponent,
  TransferResult,
} from '../../../shared/transfer-modal/transfer-modal.component';

type OpenDialog = 'resolve' | 'transfer' | 'alert' | null;

@Component({
  selector: 'app-ticket-actions-bar',
  standalone: true,
  imports: [ConfirmDialogComponent, TransferModalComponent, EngineeringAlertModalComponent],
  templateUrl: './ticket-actions-bar.component.html',
  styleUrl: './ticket-actions-bar.component.scss',
})
export class TicketActionsBarComponent {
  readonly ticket = input.required<TicketDetail>();
  readonly actions = input.required<TicketAction[]>();
  readonly busy = input(false);

  readonly assume = output<void>();
  readonly resolve = output<void>();
  readonly transferred = output<TransferResult>();
  readonly alertRaised = output<TicketDetail>();
  readonly failed = output<unknown>();

  readonly dialog = signal<OpenDialog>(null);

  has(action: TicketAction): boolean {
    return this.actions().includes(action);
  }

  confirmResolve(): void {
    this.dialog.set(null);
    this.resolve.emit();
  }

  onTransferred(result: TransferResult): void {
    this.dialog.set(null);
    this.transferred.emit(result);
  }

  onAlertRaised(ticket: TicketDetail): void {
    this.dialog.set(null);
    this.alertRaised.emit(ticket);
  }

  onFailed(error: unknown): void {
    this.dialog.set(null);
    this.failed.emit(error);
  }
}
