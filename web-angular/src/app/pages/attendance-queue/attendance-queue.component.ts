import { Component, computed, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable, toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router } from '@angular/router';
import { EMPTY, merge, Subject, switchMap } from 'rxjs';

import { TicketSummary } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { FlashMessageService } from '../../core/services/flash-message.service';
import { TicketService } from '../../core/services/ticket.service';
import { actionErrorMessage, apiErrorMessage, httpStatus } from '../../core/utils/api-error';
import { poll } from '../../core/utils/polling';
import {
  badgeClass,
  isSlaRunning,
  PRESENCE_LABELS,
  PRIORITY_LABELS,
  SLA_LABELS,
  STATUS_LABELS,
} from '../../core/utils/ticket-labels';
import { canAssumeFromQueue, Viewer } from '../../core/utils/ticket-permissions';
import { relativeTime, slaDueLabel } from '../../core/utils/time-format';
import { TimedMessage } from '../../core/utils/timed-message';
import { ErrorBannerComponent } from '../../shared/error-banner/error-banner.component';
import { SuccessToastComponent } from '../../shared/success-toast/success-toast.component';
import { QUEUE_TABS, QueueTab, resolveQueueView, sameQueueView, visibleTabs } from './queue-tabs';

const QUEUE_POLL_MS = 15_000;

@Component({
  selector: 'app-attendance-queue',
  standalone: true,
  imports: [ErrorBannerComponent, SuccessToastComponent],
  templateUrl: './attendance-queue.component.html',
  styleUrl: './attendance-queue.component.scss',
})
export class AttendanceQueueComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly tickets = inject(TicketService);
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);
  private readonly reload = new Subject<void>();
  private readonly queryParams = toSignal(this.route.queryParamMap, { requireSync: true });

  readonly me = this.employees.me;
  readonly isAdmin = this.auth.isAdmin();
  readonly tabs = computed(() => {
    const me = this.me();
    return me === undefined ? [] : visibleTabs(me !== null, this.isAdmin);
  });
  readonly view = computed(
    () =>
      resolveQueueView(
        this.queryParams().get('aba'),
        this.queryParams().get('status'),
        this.tabs(),
      ),
    { equal: sameQueueView },
  );
  private readonly viewer = computed<Viewer | null>(() => {
    const me = this.me();
    if (me === undefined) {
      return null;
    }
    return {
      userId: this.auth.currentUser()?.id ?? -1,
      isAdmin: this.isAdmin,
      employeeId: me?.id ?? null,
    };
  });

  readonly rows = signal<TicketSummary[] | null>(null);
  readonly offline = signal(false);
  readonly busyId = signal<number | null>(null);
  readonly errorMessage = signal('');
  readonly now = signal(Date.now());
  readonly toast = new TimedMessage();

  readonly tabConfig = QUEUE_TABS;
  readonly statusLabels = STATUS_LABELS;
  readonly priorityLabels = PRIORITY_LABELS;
  readonly slaLabels = SLA_LABELS;
  readonly presenceLabels = PRESENCE_LABELS;
  readonly badgeClass = badgeClass;
  readonly isSlaRunning = isSlaRunning;

  constructor() {
    const notice = inject(FlashMessageService).take();
    if (notice) {
      this.toast.show(notice);
    }
    inject(DestroyRef).onDestroy(() => this.toast.clear());

    // Trocar de aba ou de status reinicia o polling; mudar a presença recarrega na hora,
    // porque ficar Online dispara o roteamento.
    toObservable(this.view)
      .pipe(
        switchMap((view) => {
          this.rows.set(null);
          if (!view) {
            return EMPTY;
          }
          return poll(
            () => this.tickets.queue(QUEUE_TABS[view.tab].scope, view.status),
            QUEUE_POLL_MS,
            merge(this.reload, this.employees.presenceChanged$),
          );
        }),
        takeUntilDestroyed(),
      )
      .subscribe((event) => {
        if (event.ok) {
          this.rows.set(event.value);
          this.offline.set(false);
          this.now.set(Date.now());
        } else {
          this.offline.set(true);
        }
      });
  }

  selectTab(tab: QueueTab): void {
    this.router.navigate([], { relativeTo: this.route, queryParams: { aba: tab } });
  }

  selectStatus(status: string): void {
    const view = this.view();
    if (!view) {
      return;
    }
    this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { aba: view.tab, status: status || null },
    });
  }

  canAssume(row: TicketSummary): boolean {
    const viewer = this.viewer();
    const view = this.view();
    return !!viewer && !!view && canAssumeFromQueue(row, view.tab === 'minha', viewer);
  }

  open(row: TicketSummary): void {
    this.router.navigate(['/atendimento', row.id]);
  }

  assume(row: TicketSummary, event: Event): void {
    event.stopPropagation();
    if (this.busyId() !== null) {
      return;
    }
    this.busyId.set(row.id);

    this.tickets.assume(row.id).subscribe({
      next: () => {
        this.busyId.set(null);
        this.errorMessage.set('');
        this.router.navigate(['/atendimento', row.id]);
      },
      error: (error) => {
        this.busyId.set(null);
        this.errorMessage.set(actionErrorMessage(error));
        if (httpStatus(error) === 409) {
          this.reload.next();
        }
      },
    });
  }

  goOnline(): void {
    this.employees.changePresence('ONLINE').subscribe({
      next: () => this.errorMessage.set(''),
      error: (error) =>
        this.errorMessage.set(apiErrorMessage(error, 'Não foi possível mudar a presença.')),
    });
  }

  slaDue(iso: string | null): string {
    return slaDueLabel(iso, this.now());
  }

  relative(iso: string): string {
    return relativeTime(iso, this.now());
  }
}
