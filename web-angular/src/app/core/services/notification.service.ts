import { inject, Injectable, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { map, Observable, tap } from 'rxjs';

import { AppNotification } from '../models/ticket.model';

/** GET /notifications devolve no máximo 50. */
export const UNREAD_LIMIT = 50;

export function unreadBadge(count: number): string {
  return count >= UNREAD_LIMIT ? `${UNREAD_LIMIT}+` : String(count);
}

@Injectable({ providedIn: 'root' })
export class NotificationService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  private readonly unreadState = signal(0);

  readonly unreadCount = this.unreadState.asReadonly();

  list(): Observable<AppNotification[]> {
    return this.http.get<AppNotification[]>(`${this.apiUrl}/notifications`);
  }

  refreshUnread(): Observable<number> {
    const params = new HttpParams().set('unreadOnly', 'true');

    return this.http
      .get<AppNotification[]>(`${this.apiUrl}/notifications`, { params })
      .pipe(
        map(list => list.length),
        tap(count => this.unreadState.set(count))
      );
  }

  markRead(notification: AppNotification): Observable<void> {
    return this.http
      .post<void>(`${this.apiUrl}/notifications/${notification.id}/read`, null)
      .pipe(
        tap(() => {
          if (!notification.read) {
            this.unreadState.update(count => Math.max(0, count - 1));
          }
        })
      );
  }

  markAllRead(): Observable<void> {
    return this.http
      .post<void>(`${this.apiUrl}/notifications/read-all`, null)
      .pipe(tap(() => this.unreadState.set(0)));
  }

  clear(): void {
    this.unreadState.set(0);
  }
}
