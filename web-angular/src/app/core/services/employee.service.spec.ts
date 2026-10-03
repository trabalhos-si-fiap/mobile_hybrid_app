import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { Presence } from '../models/ticket.model';
import { anEmployee } from '../../testing/test-data';
import { EmployeeService } from './employee.service';

const ME_URL = '/api/v1/employees/me';
const PRESENCE_URL = '/api/v1/employees/me/presence';

describe('EmployeeService', () => {
  let service: EmployeeService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(EmployeeService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    vi.useRealTimers();
    http.verify();
  });

  it('starts as loading', () => {
    expect(service.me()).toBeUndefined();
  });

  it('loads the agent', () => {
    service.load().subscribe();
    http.expectOne(ME_URL).flush(anEmployee());

    expect(service.me()).toEqual(anEmployee());
  });

  it('treats a 403 as staff without an agent record', () => {
    service.load().subscribe();
    http
      .expectOne(ME_URL)
      .flush({ message: 'não é atendente' }, { status: 403, statusText: 'Forbidden' });

    expect(service.me()).toBeNull();
  });

  it('flags a failure that is not a 403 nor transient and stays on loading', () => {
    expect(service.loadFailed()).toBe(false);

    service.load().subscribe({ error: () => undefined });
    http.expectOne(ME_URL).flush({}, { status: 404, statusText: 'Not Found' });

    expect(service.loadFailed()).toBe(true);
    expect(service.me()).toBeUndefined();
  });

  it('clears the failure when it loads again', () => {
    service.load().subscribe({ error: () => undefined });
    http.expectOne(ME_URL).flush({}, { status: 404, statusText: 'Not Found' });

    service.load().subscribe();
    expect(service.loadFailed()).toBe(false);

    http.expectOne(ME_URL).flush(anEmployee());
    expect(service.me()).toEqual(anEmployee());
  });

  it('forgets the previous agent while loading again', () => {
    service.load().subscribe();
    http.expectOne(ME_URL).flush(anEmployee());

    service.load().subscribe();
    expect(service.me()).toBeUndefined();

    http.expectOne(ME_URL).flush(anEmployee({ id: 8, name: 'Rita' }));
    expect(service.me()?.name).toBe('Rita');
  });

  it('retries a transient failure after 5 s', () => {
    vi.useFakeTimers();
    service.load().subscribe();

    http.expectOne(ME_URL).flush({}, { status: 503, statusText: 'Unavailable' });
    expect(service.me()).toBeUndefined();

    vi.advanceTimersByTime(5000);
    http.expectOne(ME_URL).flush(anEmployee());
    expect(service.me()).toEqual(anEmployee());
  });

  it('changes the presence, keeps the answer and announces it', () => {
    const changes: Presence[] = [];
    service.presenceChanged$.subscribe((presence) => changes.push(presence));

    service.changePresence('AUSENTE').subscribe();
    const request = http.expectOne(PRESENCE_URL);
    expect(request.request.method).toBe('PUT');
    expect(request.request.body).toEqual({ presence: 'AUSENTE' });
    request.flush(anEmployee({ presence: 'AUSENTE' }));

    expect(service.me()?.presence).toBe('AUSENTE');
    expect(changes).toEqual(['AUSENTE']);
  });

  it('does not announce a failed presence change', () => {
    const changes: Presence[] = [];
    service.presenceChanged$.subscribe((presence) => changes.push(presence));

    service.changePresence('ONLINE').subscribe({ error: () => undefined });
    http.expectOne(PRESENCE_URL).flush({}, { status: 500, statusText: 'Error' });

    expect(changes).toEqual([]);
  });

  it('goOffline sends OFFLINE and completes even when it fails', () => {
    let done = false;
    service.goOffline().subscribe({ complete: () => (done = true) });

    const request = http.expectOne(PRESENCE_URL);
    expect(request.request.body).toEqual({ presence: 'OFFLINE' });
    request.flush({}, { status: 500, statusText: 'Error' });

    expect(done).toBe(true);
  });

  it('goOffline gives up after 3 s so the logout is never stuck', () => {
    vi.useFakeTimers();
    let done = false;
    service.goOffline().subscribe({ complete: () => (done = true) });
    const request = http.expectOne(PRESENCE_URL);

    vi.advanceTimersByTime(2999);
    expect(done).toBe(false);
    vi.advanceTimersByTime(1);

    expect(done).toBe(true);
    expect(request.cancelled).toBe(true);
  });

  it('clear goes back to loading', () => {
    service.load().subscribe();
    http.expectOne(ME_URL).flush(anEmployee());

    service.clear();

    expect(service.me()).toBeUndefined();
  });
});
