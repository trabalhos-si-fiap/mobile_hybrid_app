import { Component, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable } from '@angular/core/rxjs-interop';
import { EMPTY, Subject, switchMap } from 'rxjs';

import { Presence } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { NotificationService, unreadBadge } from '../../core/services/notification.service';
import { apiErrorMessage } from '../../core/utils/api-error';
import { poll } from '../../core/utils/polling';
import { formatTime } from '../../core/utils/time-format';
import { NotificationPanelComponent } from '../notification-panel/notification-panel.component';

const UNREAD_POLL_MS = 30_000;

@Component({
  selector: 'app-agent-card',
  standalone: true,
  imports: [NotificationPanelComponent],
  templateUrl: './agent-card.component.html',
  styleUrl: './agent-card.component.scss',
})
export class AgentCardComponent {
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);
  private readonly notifications = inject(NotificationService);
  private readonly unreadReload = new Subject<void>();

  readonly me = this.employees.me;
  private readonly isAgent = computed(() => !!this.me());
  readonly userName = this.auth.currentUser()?.name ?? '';
  readonly saving = signal(false);
  readonly error = signal('');
  readonly panelOpen = signal(false);
  readonly since = computed(() => formatTime(this.me()?.presenceChangedAt));
  readonly hasUnread = computed(() => this.notifications.unreadCount() > 0);
  readonly unreadLabel = computed(() => unreadBadge(this.notifications.unreadCount()));

  constructor() {
    // Staff sem cadastro de atendente não tem sino: nada a consultar.
    toObservable(this.isAgent)
      .pipe(
        switchMap((agent) =>
          agent
            ? poll(() => this.notifications.refreshUnread(), UNREAD_POLL_MS, this.unreadReload)
            : EMPTY,
        ),
        takeUntilDestroyed(),
      )
      .subscribe();
  }

  togglePanel(): void {
    this.panelOpen.update((open) => !open);
  }

  closePanel(): void {
    this.panelOpen.set(false);
    this.unreadReload.next();
  }

  /** Recebe o próprio select para devolvê-lo ao valor anterior se a API recusar. */
  changePresence(select: HTMLSelectElement): void {
    const previous = this.me()?.presence;
    const next = select.value as Presence;

    if (!previous || next === previous || this.saving()) {
      return;
    }

    this.saving.set(true);
    this.error.set('');

    this.employees.changePresence(next).subscribe({
      next: () => this.saving.set(false),
      error: (error) => {
        this.saving.set(false);
        select.value = previous;
        this.error.set(apiErrorMessage(error, 'Não foi possível mudar a presença.'));
      },
    });
  }
}
