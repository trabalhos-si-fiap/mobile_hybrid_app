import { Component, inject, input, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import { catchError, EMPTY, Observable, startWith, Subject, switchMap, tap } from 'rxjs';

import { ChatbotMessage } from '../../../core/models/chatbot.model';
import { TicketService } from '../../../core/services/ticket.service';
import { httpStatus } from '../../../core/utils/api-error';
import { formatTime } from '../../../core/utils/time-format';

const BOT_NAME = 'Mentor Edu';

type LoadState = 'loading' | 'ready' | 'missing' | 'failed';

@Component({
  selector: 'app-ticket-chatbot-transcript',
  standalone: true,
  templateUrl: './ticket-chatbot-transcript.component.html',
  styleUrl: './ticket-chatbot-transcript.component.scss',
})
export class TicketChatbotTranscriptComponent {
  private readonly tickets = inject(TicketService);
  private readonly retries = new Subject<void>();

  readonly ticketId = input.required<number>();
  readonly requesterName = input.required<string>();

  readonly state = signal<LoadState>('loading');
  readonly messages = signal<ChatbotMessage[]>([]);

  constructor() {
    // A conversa não muda depois da passagem: carrega uma vez por id. O polling do detalhe
    // entrega um ticket novo com o mesmo id, e o input numérico não muda com isso.
    toObservable(this.ticketId)
      .pipe(
        switchMap((id) =>
          this.retries.pipe(
            startWith(undefined),
            switchMap(() => this.load(id)),
          ),
        ),
        takeUntilDestroyed(),
      )
      .subscribe();
  }

  retry(): void {
    this.retries.next();
  }

  sender(message: ChatbotMessage): string {
    return message.sender === 'BOT' ? BOT_NAME : this.requesterName();
  }

  time(iso: string): string {
    return formatTime(iso);
  }

  private load(id: number): Observable<unknown> {
    this.state.set('loading');
    this.messages.set([]);

    return this.tickets.chatbotConversation(id).pipe(
      tap((transcript) => {
        this.messages.set(transcript.messages);
        this.state.set('ready');
      }),
      catchError((error) => {
        // 404: o ticket não tem conversa ligada, então o bloco some.
        this.state.set(httpStatus(error) === 404 ? 'missing' : 'failed');
        return EMPTY;
      }),
    );
  }
}
