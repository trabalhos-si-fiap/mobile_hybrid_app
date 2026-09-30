import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, Router } from '@angular/router';

import { NotificationService } from '../services/notification.service';
import { authInterceptor } from './auth.interceptor';

describe('authInterceptor', () => {
  let http: HttpClient;
  let controller: HttpTestingController;
  let router: Router;

  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpClient);
    controller = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);

    localStorage.setItem('edu_admin_token', 'jwt');
    localStorage.setItem(
      'edu_admin_user',
      JSON.stringify({ id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' }),
    );
  });

  afterEach(() => controller.verify());

  it('sends the Bearer token', () => {
    http.get('/api/v1/tickets/queue').subscribe();

    const request = controller.expectOne('/api/v1/tickets/queue');
    expect(request.request.headers.get('Authorization')).toBe('Bearer jwt');
    request.flush([]);
  });

  it('logs out and goes to the login on a 401', () => {
    http.get('/api/v1/tickets/queue').subscribe({ error: () => undefined });

    controller
      .expectOne('/api/v1/tickets/queue')
      .flush({ message: 'Token expirado' }, { status: 401, statusText: 'Unauthorized' });

    expect(localStorage.getItem('edu_admin_token')).toBeNull();
    expect(router.navigate).toHaveBeenCalledWith(['/login'], {
      queryParams: { sessao: 'expirada' },
    });
  });

  it('clears the previous account state on a 401', () => {
    const notifications = TestBed.inject(NotificationService);
    notifications.refreshUnread().subscribe();
    controller.expectOne((req) => req.url.endsWith('/notifications')).flush([{ id: 1 }, { id: 2 }]);
    expect(notifications.unreadCount()).toBe(2);

    http.get('/api/v1/tickets/queue').subscribe({ error: () => undefined });
    controller
      .expectOne('/api/v1/tickets/queue')
      .flush({}, { status: 401, statusText: 'Unauthorized' });

    expect(notifications.unreadCount()).toBe(0);
  });

  it('leaves a 401 from the login itself alone', () => {
    http.post('/api/v1/auth/login', {}).subscribe({ error: () => undefined });

    const request = controller.expectOne('/api/v1/auth/login');
    expect(request.request.headers.has('Authorization')).toBe(false);
    request.flush({}, { status: 401, statusText: 'Unauthorized' });

    expect(router.navigate).not.toHaveBeenCalled();
    expect(localStorage.getItem('edu_admin_token')).toBe('jwt');
  });

  it('passes other errors through without logging out', () => {
    let status = 0;
    http.get('/api/v1/tickets/queue').subscribe({ error: (error) => (status = error.status) });

    controller
      .expectOne('/api/v1/tickets/queue')
      .flush({}, { status: 403, statusText: 'Forbidden' });

    expect(status).toBe(403);
    expect(localStorage.getItem('edu_admin_token')).toBe('jwt');
  });
});
