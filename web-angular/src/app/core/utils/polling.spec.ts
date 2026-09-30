import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { delay, of, Subject, throwError } from 'rxjs';

import { poll, PollEvent } from './polling';

describe('poll', () => {
  let visibility: DocumentVisibilityState;

  beforeEach(() => {
    vi.useFakeTimers();
    visibility = 'visible';
    vi.spyOn(document, 'visibilityState', 'get').mockImplementation(() => visibility);
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  function setVisibility(state: DocumentVisibilityState): void {
    visibility = state;
    document.dispatchEvent(new Event('visibilitychange'));
  }

  it('fetches at once and then every interval', () => {
    const source = vi.fn(() => of(1));
    const subscription = poll(source, 1000).subscribe();

    expect(source).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(999);
    expect(source).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(1);
    expect(source).toHaveBeenCalledTimes(2);

    subscription.unsubscribe();
  });

  it('pauses while the tab is hidden and fetches when it is visible again', () => {
    const source = vi.fn(() => of(1));
    const subscription = poll(source, 1000).subscribe();

    setVisibility('hidden');
    vi.advanceTimersByTime(5000);
    expect(source).toHaveBeenCalledTimes(1);

    setVisibility('visible');
    expect(source).toHaveBeenCalledTimes(2);

    subscription.unsubscribe();
  });

  it('reload fetches now and restarts the interval', () => {
    const source = vi.fn(() => of(1));
    const reload = new Subject<void>();
    const subscription = poll(source, 1000, reload).subscribe();

    vi.advanceTimersByTime(600);
    reload.next();
    expect(source).toHaveBeenCalledTimes(2);

    vi.advanceTimersByTime(600);
    expect(source).toHaveBeenCalledTimes(2);
    vi.advanceTimersByTime(400);
    expect(source).toHaveBeenCalledTimes(3);

    subscription.unsubscribe();
  });

  it('turns an error into an event and keeps polling', () => {
    let calls = 0;
    const events: PollEvent<number>[] = [];
    const subscription = poll(
      () => (++calls === 1 ? throwError(() => new Error('rede')) : of(calls)),
      1000
    ).subscribe(event => events.push(event));

    vi.advanceTimersByTime(1000);

    expect(events).toEqual([
      { ok: false, error: new Error('rede') },
      { ok: true, value: 2 }
    ]);
    subscription.unsubscribe();
  });

  it('drops a late response once a newer fetch has started', () => {
    const values: number[] = [];
    const reload = new Subject<void>();
    let calls = 0;
    const subscription = poll(
      () => {
        calls++;
        return of(calls).pipe(delay(calls === 1 ? 500 : 10));
      },
      10_000,
      reload
    ).subscribe(event => {
      if (event.ok) {
        values.push(event.value);
      }
    });

    vi.advanceTimersByTime(100);
    reload.next();
    vi.advanceTimersByTime(1000);

    expect(values).toEqual([2]);
    subscription.unsubscribe();
  });

  it('stops when unsubscribed', () => {
    const source = vi.fn(() => of(1));
    poll(source, 1000).subscribe().unsubscribe();

    vi.advanceTimersByTime(5000);

    expect(source).toHaveBeenCalledTimes(1);
  });
});
