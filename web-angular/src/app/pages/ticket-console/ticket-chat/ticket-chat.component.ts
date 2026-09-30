import {
  afterRenderEffect,
  Component,
  computed,
  ElementRef,
  inject,
  input,
  output,
  signal,
  viewChild
} from '@angular/core';

import { TicketMessage } from '../../../core/models/ticket.model';
import { TicketService } from '../../../core/services/ticket.service';
import { apiErrorMessage, httpStatus } from '../../../core/utils/api-error';
import {
  ACCEPT_ATTRIBUTE,
  addFiles,
  formatBytes,
  MAX_BODY_LENGTH,
  messageProblem
} from '../../../core/utils/attachment-rules';
import { formatTime } from '../../../core/utils/time-format';
import { AttachmentViewComponent } from '../../../shared/attachment-view/attachment-view.component';

/** Distância do fim (px) em que ainda consideramos que o atendente está lendo as últimas mensagens. */
const NEAR_BOTTOM_PX = 80;

@Component({
  selector: 'app-ticket-chat',
  standalone: true,
  imports: [AttachmentViewComponent],
  templateUrl: './ticket-chat.component.html',
  styleUrl: './ticket-chat.component.scss'
})
export class TicketChatComponent {
  private readonly tickets = inject(TicketService);

  readonly ticketId = input.required<number>();
  readonly messages = input.required<TicketMessage[]>();
  readonly blockReason = input<string | null>(null);

  readonly sent = output<TicketMessage>();
  readonly failed = output<unknown>();

  readonly body = signal('');
  readonly files = signal<File[]>([]);
  readonly sending = signal(false);
  readonly error = signal('');
  readonly tooLong = computed(() => this.body().trim().length > MAX_BODY_LENGTH);

  readonly maxLength = MAX_BODY_LENGTH;
  readonly accept = ACCEPT_ATTRIBUTE;

  private readonly list = viewChild<ElementRef<HTMLElement>>('list');
  private stickToBottom = true;
  private renderedCount = 0;

  constructor() {
    // Rola para o fim quando chega mensagem nova, se o atendente já estava perto do fim.
    afterRenderEffect(() => {
      const count = this.messages().length;
      const element = this.list()?.nativeElement;
      if (!element || count === this.renderedCount) {
        return;
      }
      this.renderedCount = count;
      if (this.stickToBottom) {
        element.scrollTop = element.scrollHeight;
      }
    });
  }

  onScroll(element: HTMLElement): void {
    this.stickToBottom =
      element.scrollHeight - element.scrollTop - element.clientHeight < NEAR_BOTTOM_PX;
  }

  onKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Enter' || event.shiftKey || event.isComposing) {
      return;
    }
    event.preventDefault();
    this.send();
  }

  pickFiles(picker: HTMLInputElement): void {
    const result = addFiles(this.files(), Array.from(picker.files ?? []));
    this.files.set(result.files);
    this.error.set(result.problems.join(' '));
    // Permite escolher de novo o mesmo arquivo depois de removê-lo.
    picker.value = '';
  }

  removeFile(index: number): void {
    this.files.update(files => files.filter((_, i) => i !== index));
  }

  send(): void {
    if (this.sending()) {
      return;
    }

    const problem = messageProblem(this.body(), this.files());
    if (problem) {
      this.error.set(problem);
      return;
    }

    this.sending.set(true);
    this.error.set('');

    this.tickets.sendMessage(this.ticketId(), this.body().trim(), this.files()).subscribe({
      next: message => {
        this.sending.set(false);
        this.body.set('');
        this.files.set([]);
        this.stickToBottom = true;
        this.sent.emit(message);
      },
      error: error => {
        this.sending.set(false);
        if (httpStatus(error) === 400) {
          this.error.set(apiErrorMessage(error, 'Confira a mensagem e os anexos.'));
          return;
        }
        this.failed.emit(error);
      }
    });
  }

  time(iso: string): string {
    return formatTime(iso);
  }

  size(bytes: number): string {
    return formatBytes(bytes);
  }
}
