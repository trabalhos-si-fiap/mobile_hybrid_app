import { Component, computed, input } from '@angular/core';

import { TicketDetail, TicketEvent } from '../../../core/models/ticket.model';
import {
  badgeClass,
  CHANNEL_LABELS,
  isSlaRunning,
  QUEUE_LABELS,
  SLA_LABELS
} from '../../../core/utils/ticket-labels';
import { formatDateTime, slaDueLabel } from '../../../core/utils/time-format';
import { AttachmentViewComponent } from '../../../shared/attachment-view/attachment-view.component';
import { TicketTimelineComponent } from '../ticket-timeline/ticket-timeline.component';

@Component({
  selector: 'app-ticket-info-panel',
  standalone: true,
  imports: [AttachmentViewComponent, TicketTimelineComponent],
  templateUrl: './ticket-info-panel.component.html',
  styleUrl: './ticket-info-panel.component.scss'
})
export class TicketInfoPanelComponent {
  readonly ticket = input.required<TicketDetail>();
  readonly events = input.required<TicketEvent[]>();
  /** Relógio do último polling, para os tempos relativos. */
  readonly now = input.required<number>();

  readonly queueLabels = QUEUE_LABELS;
  readonly channelLabels = CHANNEL_LABELS;
  readonly slaLabels = SLA_LABELS;
  readonly badgeClass = badgeClass;

  readonly dates = computed(() => {
    const ticket = this.ticket();
    return [
      { label: 'Aberto em', value: ticket.createdAt },
      { label: 'Assumido em', value: ticket.assumedAt },
      { label: 'Resolvido em', value: ticket.resolvedAt },
      { label: 'Fechado em', value: ticket.closedAt }
    ]
      .filter(date => !!date.value)
      .map(date => ({ label: date.label, value: formatDateTime(date.value) }));
  });

  readonly slaDue = computed(() => formatDateTime(this.ticket().slaDueAt));
  readonly slaRelative = computed(() =>
    isSlaRunning(this.ticket().slaStatus) ? slaDueLabel(this.ticket().slaDueAt, this.now()) : ''
  );
}
