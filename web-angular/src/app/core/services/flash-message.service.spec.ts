import { describe, expect, it } from 'vitest';

import { FlashMessageService } from './flash-message.service';

describe('FlashMessageService', () => {
  it('hands the message over once', () => {
    const flash = new FlashMessageService();

    flash.set('Ticket #12 transferido para Feedback / Sugestões');

    expect(flash.take()).toBe('Ticket #12 transferido para Feedback / Sugestões');
    expect(flash.take()).toBeNull();
  });
});
