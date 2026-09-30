import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { TimedMessage } from './timed-message';

describe('TimedMessage', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('shows a text and hides it after the duration', () => {
    const message = new TimedMessage(3200);

    message.show('Ticket assumido.');
    expect(message.text()).toBe('Ticket assumido.');

    vi.advanceTimersByTime(3199);
    expect(message.text()).toBe('Ticket assumido.');
    vi.advanceTimersByTime(1);
    expect(message.text()).toBe('');
  });

  it('restarts the countdown when a new text arrives', () => {
    const message = new TimedMessage(1000);

    message.show('primeiro');
    vi.advanceTimersByTime(800);
    message.show('segundo');
    vi.advanceTimersByTime(800);

    expect(message.text()).toBe('segundo');
  });

  it('clear hides at once', () => {
    const message = new TimedMessage(1000);

    message.show('x');
    message.clear();

    expect(message.text()).toBe('');
  });
});
