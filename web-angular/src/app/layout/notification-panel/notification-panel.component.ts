import { Component, computed, inject, output, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';

import { AppNotification } from '../../core/models/ticket.model';
import { NotificationService } from '../../core/services/notification.service';
import { relativeTime } from '../../core/utils/time-format';

@Component({
  selector: 'app-notification-panel',
  standalone: true,
  templateUrl: './notification-panel.component.html',
  styleUrl: './notification-panel.component.scss',
  host: { '(document:keydown.escape)': 'closed.emit()' },
})
export class NotificationPanelComponent {
  private readonly notifications = inject(NotificationService);
  private readonly router = inject(Router);

  readonly closed = output<void>();

  readonly items = signal<AppNotification[] | null>(null);
  readonly error = signal('');
  readonly hasUnread = computed(() => (this.items() ?? []).some((item) => !item.read));
  private readonly now = Date.now();

  constructor() {
    this.notifications
      .list()
      .pipe(takeUntilDestroyed())
      .subscribe({
        next: (list) => this.items.set(list),
        error: () => {
          this.items.set([]);
          this.error.set('Não foi possível carregar as notificações.');
        },
      });
  }

  open(item: AppNotification): void {
    this.markLocally(item.id);
    // Sem takeUntilDestroyed: a marcação precisa terminar mesmo com o painel já fechado.
    this.notifications.markRead(item).subscribe({
      error: () => {
        this.markUnread(item);
        this.error.set('Não foi possível marcar a notificação como lida.');
      },
    });

    if (item.ticketId !== null) {
      this.router.navigate(['/atendimento', item.ticketId]);
      this.closed.emit();
    }
  }

  markAll(): void {
    this.notifications.markAllRead().subscribe({
      next: () =>
        this.items.update((list) => list?.map((item) => ({ ...item, read: true })) ?? list),
      error: () => this.error.set('Não foi possível marcar as notificações.'),
    });
  }

  relative(iso: string): string {
    return relativeTime(iso, this.now);
  }

  private markLocally(id: number): void {
    this.items.update(
      (list) => list?.map((item) => (item.id === id ? { ...item, read: true } : item)) ?? list,
    );
  }

  private markUnread(original: AppNotification): void {
    if (original.read) {
      return;
    }
    this.items.update(
      (list) =>
        list?.map((item) => (item.id === original.id ? { ...item, read: false } : item)) ?? list,
    );
  }
}
