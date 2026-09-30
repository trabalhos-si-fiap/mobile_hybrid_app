import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { aNotification } from '../../testing/test-data';
import { NotificationService, unreadBadge } from './notification.service';

describe('NotificationService', () => {
  let service: NotificationService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(NotificationService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  function refresh(count: number): void {
    service.refreshUnread().subscribe();
    const request = http.expectOne((req) => req.url === '/api/v1/notifications');
    expect(request.request.params.get('unreadOnly')).toBe('true');
    request.flush(Array.from({ length: count }, (_, i) => aNotification({ id: i + 1 })));
  }

  it('counts the unread notifications', () => {
    refresh(3);

    expect(service.unreadCount()).toBe(3);
  });

  it('lists the latest notifications', () => {
    service.list().subscribe();

    const request = http.expectOne('/api/v1/notifications');
    expect(request.request.params.has('unreadOnly')).toBe(false);
    request.flush([]);
  });

  it('marks one as read and takes it off the count only if it was unread', () => {
    refresh(2);

    service.markRead(aNotification({ id: 1 })).subscribe();
    const request = http.expectOne('/api/v1/notifications/1/read');
    expect(request.request.method).toBe('POST');
    request.flush(null, { status: 204, statusText: 'No Content' });
    expect(service.unreadCount()).toBe(1);

    service.markRead(aNotification({ id: 2, read: true })).subscribe();
    http
      .expectOne('/api/v1/notifications/2/read')
      .flush(null, { status: 204, statusText: 'No Content' });
    expect(service.unreadCount()).toBe(1);
  });

  it('marks all as read', () => {
    refresh(4);

    service.markAllRead().subscribe();
    const request = http.expectOne('/api/v1/notifications/read-all');
    expect(request.request.method).toBe('POST');
    request.flush(null, { status: 204, statusText: 'No Content' });

    expect(service.unreadCount()).toBe(0);
  });

  it('shows 50+ when the API returns its maximum', () => {
    expect(unreadBadge(0)).toBe('0');
    expect(unreadBadge(49)).toBe('49');
    expect(unreadBadge(50)).toBe('50+');
  });
});
