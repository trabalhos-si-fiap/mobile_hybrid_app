import { Component, input, signal } from '@angular/core';

import { TicketEvent } from '../../../core/models/ticket.model';
import { EVENT_LABELS, STATUS_LABELS } from '../../../core/utils/ticket-labels';
import { formatDateTime } from '../../../core/utils/time-format';

@Component({
  selector: 'app-ticket-timeline',
  standalone: true,
  templateUrl: './ticket-timeline.component.html',
  styleUrl: './ticket-timeline.component.scss',
})
export class TicketTimelineComponent {
  readonly events = input.required<TicketEvent[]>();

  readonly expanded = signal(false);
  readonly eventLabels = EVENT_LABELS;

  transition(event: TicketEvent): string {
    if (event.fromStatus && event.toStatus) {
      return `${STATUS_LABELS[event.fromStatus]} → ${STATUS_LABELS[event.toStatus]}`;
    }
    return '';
  }

  date(iso: string): string {
    return formatDateTime(iso);
  }
}
