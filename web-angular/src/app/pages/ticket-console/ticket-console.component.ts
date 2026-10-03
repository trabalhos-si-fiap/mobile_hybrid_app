import { Component, computed, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import {
  distinctUntilChanged,
  EMPTY,
  forkJoin,
  map,
  merge,
  Observable,
  Subject,
  switchMap,
  takeUntil,
  tap,
} from 'rxjs';

import { TicketDetail, TicketEvent, TicketMessage } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { FlashMessageService } from '../../core/services/flash-message.service';
import { QueueParamsService } from '../../core/services/queue-params.service';
import { TicketService } from '../../core/services/ticket.service';
import { actionErrorMessage, httpStatus } from '../../core/utils/api-error';
import { poll } from '../../core/utils/polling';
import {
  badgeClass,
  PRIORITY_LABELS,
  SLA_LABELS,
  STATUS_LABELS,
} from '../../core/utils/ticket-labels';
import { availableActions, chatBlockReason, Viewer } from '../../core/utils/ticket-permissions';
import { TimedMessage } from '../../core/utils/timed-message';
import { ErrorBannerComponent } from '../../shared/error-banner/error-banner.component';
import { SuccessToastComponent } from '../../shared/success-toast/success-toast.component';
import { TransferResult } from '../../shared/transfer-modal/transfer-modal.component';
import { TicketActionsBarComponent } from './ticket-actions-bar/ticket-actions-bar.component';
import { TicketChatComponent } from './ticket-chat/ticket-chat.component';
import { TicketInfoPanelComponent } from './ticket-info-panel/ticket-info-panel.component';

const MESSAGES_POLL_MS = 5_000;
const DETAIL_POLL_MS = 15_000;

type PollName = 'detail' | 'messages';

@Component({
  selector: 'app-ticket-console',
  standalone: true,
  imports: [
    RouterLink,
    TicketInfoPanelComponent,
    TicketChatComponent,
    TicketActionsBarComponent,
    ErrorBannerComponent,
    SuccessToastComponent,
  ],
  templateUrl: './ticket-console.component.html',
  styleUrl: './ticket-console.component.scss',
})
export class TicketConsoleComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly tickets = inject(TicketService);
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);
  private readonly flash = inject(FlashMessageService);
  /** A fila que o atendente estava vendo; lida uma vez, porque a fila fecha antes do console abrir. */
  readonly queueParams = inject(QueueParamsService).current();
  private readonly detailReload = new Subject<void>();
  private readonly messagesReload = new Subject<void>();
  private readonly idChange = new Subject<void>();

  readonly ticket = signal<TicketDetail | null>(null);
  readonly events = signal<TicketEvent[]>([]);
  readonly messages = signal<TicketMessage[]>([]);
  readonly notFound = signal(false);
  private readonly failedPolls = signal<ReadonlySet<PollName>>(new Set());
  readonly offline = computed(() => this.failedPolls().size > 0);
  readonly busy = signal(false);
  readonly errorMessage = signal('');
  readonly now = signal(Date.now());
  readonly toast = new TimedMessage();

  private readonly viewer = computed<Viewer | null>(() => {
    const me = this.employees.me();
    if (me === undefined) {
      return null;
    }
    return {
      userId: this.auth.currentUser()?.id ?? -1,
      isAdmin: this.auth.isAdmin(),
      employeeId: me?.id ?? null,
    };
  });
  readonly actions = computed(() => {
    const ticket = this.ticket();
    const viewer = this.viewer();
    return ticket && viewer ? availableActions(ticket, viewer) : [];
  });
  readonly blockReason = computed(() => {
    const ticket = this.ticket();
    const viewer = this.viewer();
    return ticket && viewer ? chatBlockReason(ticket, viewer) : 'Carregando...';
  });

  readonly statusLabels = STATUS_LABELS;
  readonly priorityLabels = PRIORITY_LABELS;
  readonly slaLabels = SLA_LABELS;
  readonly badgeClass = badgeClass;

  constructor() {
    inject(DestroyRef).onDestroy(() => this.toast.clear());

    // Trocar o :id (ex.: clique numa notificação) derruba os pollings do ticket anterior.
    this.route.paramMap
      .pipe(
        map((params) => Number(params.get('id'))),
        distinctUntilChanged(),
        switchMap((id) => {
          this.reset();
          if (!Number.isInteger(id) || id <= 0) {
            this.notFound.set(true);
            return EMPTY;
          }
          return this.watch(id);
        }),
        takeUntilDestroyed(),
      )
      .subscribe();
  }

  reloadAll(): void {
    this.detailReload.next();
    this.messagesReload.next();
  }

  assume(): void {
    const ticket = this.ticket();
    if (ticket) {
      this.runAction(this.tickets.assume(ticket.id), 'Ticket assumido.');
    }
  }

  resolve(): void {
    const ticket = this.ticket();
    if (ticket) {
      this.runAction(this.tickets.resolve(ticket.id), 'Ticket encerrado.');
    }
  }

  messageSent(): void {
    this.errorMessage.set('');
    this.reloadAll();
  }

  transferred(result: TransferResult): void {
    this.flash.set(`Ticket #${result.ticket.id} transferido para ${result.label}`);
    this.router.navigate(['/atendimento'], { queryParams: this.queueParams });
  }

  alertRaised(ticket: TicketDetail): void {
    if (ticket.id !== this.ticket()?.id) {
      return;
    }
    this.ticket.set(ticket);
    this.errorMessage.set('');
    this.toast.show('Alerta enviado à engenharia.');
    this.detailReload.next();
  }

  /** 409 e 404: o estado mudou por fora, então recarrega; o resto só avisa. */
  actionFailed(error: unknown): void {
    this.errorMessage.set(actionErrorMessage(error));
    const status = httpStatus(error);
    if (status === 409 || status === 404) {
      this.reloadAll();
    }
  }

  private runAction(action$: Observable<TicketDetail>, success: string): void {
    if (this.busy()) {
      return;
    }
    this.busy.set(true);

    // Uma ação iniciada no ticket anterior não pode responder depois da troca de :id.
    action$.pipe(takeUntil(this.idChange)).subscribe({
      next: (ticket) => {
        this.busy.set(false);
        this.ticket.set(ticket);
        this.errorMessage.set('');
        this.toast.show(success);
        this.reloadAll();
      },
      error: (error) => {
        this.busy.set(false);
        this.actionFailed(error);
      },
    });
  }

  private watch(id: number): Observable<unknown> {
    const stop = new Subject<void>();

    const detail$ = poll(
      () => forkJoin({ ticket: this.tickets.get(id), events: this.tickets.events(id) }),
      DETAIL_POLL_MS,
      this.detailReload,
    ).pipe(
      tap((event) => {
        if (event.ok) {
          this.ticket.set(event.value.ticket);
          this.events.set(event.value.events);
          this.polled('detail');
        } else {
          this.pollFailed('detail', event.error, stop);
        }
      }),
    );

    const messages$ = poll(
      () => this.tickets.messages(id),
      MESSAGES_POLL_MS,
      this.messagesReload,
    ).pipe(
      tap((event) => {
        if (event.ok) {
          this.messages.set(event.value);
          this.polled('messages');
        } else {
          this.pollFailed('messages', event.error, stop);
        }
      }),
    );

    return merge(detail$, messages$).pipe(takeUntil(stop));
  }

  // Cada polling marca a própria falha, para o sucesso de um não apagar o aviso do outro.
  private setFailed(name: PollName, failed: boolean): void {
    this.failedPolls.update((current) => {
      const next = new Set(current);
      if (failed) {
        next.add(name);
      } else {
        next.delete(name);
      }
      return next;
    });
  }

  private polled(name: PollName): void {
    this.setFailed(name, false);
    this.now.set(Date.now());
  }

  /** 404: o ticket sumiu da visibilidade (ex.: transferido para fora das skills); o resto é conexão. */
  private pollFailed(name: PollName, error: unknown, stop: Subject<void>): void {
    if (httpStatus(error) === 404) {
      this.notFound.set(true);
      stop.next();
      return;
    }
    this.setFailed(name, true);
  }

  private reset(): void {
    this.idChange.next();
    this.busy.set(false);
    this.ticket.set(null);
    this.events.set([]);
    this.messages.set([]);
    this.notFound.set(false);
    this.failedPolls.set(new Set());
    this.errorMessage.set('');
  }
}
