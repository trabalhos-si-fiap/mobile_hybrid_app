import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NEVER, of, throwError } from 'rxjs';

import { TicketService } from '../../../core/services/ticket.service';
import { formatDateTime, formatTime } from '../../../core/utils/time-format';
import { aChatbotMessage, aChatbotTranscript, httpError } from '../../../testing/test-data';
import { TicketChatbotTranscriptComponent } from './ticket-chatbot-transcript.component';

describe('TicketChatbotTranscriptComponent', () => {
  let chatbotConversation: Mock;

  beforeEach(() => {
    chatbotConversation = vi.fn(() => of(aChatbotTranscript()));
    TestBed.configureTestingModule({
      providers: [{ provide: TicketService, useValue: { chatbotConversation } }],
    });
  });

  async function render(
    ticketId = 12,
  ): Promise<ComponentFixture<TicketChatbotTranscriptComponent>> {
    const fixture = TestBed.createComponent(TicketChatbotTranscriptComponent);
    fixture.componentRef.setInput('ticketId', ticketId);
    fixture.componentRef.setInput('requesterName', 'Ana Usuária');
    await fixture.whenStable();
    return fixture;
  }

  function lines(fixture: ComponentFixture<TicketChatbotTranscriptComponent>): HTMLElement[] {
    return Array.from(
      fixture.nativeElement.querySelectorAll('ol[aria-label="Conversa com o chatbot"] li'),
    );
  }

  function part(line: HTMLElement, selector: string): string {
    return line.querySelector(selector)?.textContent?.trim() ?? '';
  }

  function retryButton(
    fixture: ComponentFixture<TicketChatbotTranscriptComponent>,
  ): HTMLButtonElement | undefined {
    return Array.from<HTMLButtonElement>(fixture.nativeElement.querySelectorAll('button')).find(
      (button) => button.textContent?.trim() === 'Tentar de novo',
    );
  }

  it('lists each line with the sender and the time', async () => {
    const fixture = await render();

    expect(chatbotConversation).toHaveBeenCalledWith(12);
    expect(fixture.nativeElement.querySelector('h2').textContent.trim()).toBe(
      'Conversa com o chatbot',
    );
    const [greeting, choice, handoff] = lines(fixture);
    expect(lines(fixture)).toHaveLength(3);
    expect(part(greeting, 'strong')).toBe('Mentor Edu');
    expect(part(greeting, 'time')).toBe(formatDateTime('2026-09-29T09:50:00Z'));
    expect(part(greeting, 'p')).toBe(
      'Olá, Ana! Sou o Mentor Edu, o assistente do Edu. Sobre o que você precisa de ajuda?',
    );
    expect(part(choice, 'strong')).toBe('Ana Usuária');
    expect(part(choice, 'time')).toBe(formatTime('2026-09-29T09:51:00Z'));
    expect(part(choice, 'p')).toBe('Falar com atendente');
    expect(part(handoff, 'strong')).toBe('Mentor Edu');
  });

  it('says it is loading while the conversation is on the way', async () => {
    chatbotConversation.mockReturnValue(NEVER);
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Conversa com o chatbot');
    expect(fixture.nativeElement.textContent).toContain('Carregando conversa...');
  });

  it('announces the loading state to assistive technology', async () => {
    chatbotConversation.mockReturnValue(NEVER);
    const fixture = await render();

    const status = fixture.nativeElement.querySelector('[role="status"]');
    expect(status.textContent.trim()).toBe('Carregando conversa...');
  });

  it('gives each time the exact instant in datetime', async () => {
    const fixture = await render();

    const [greeting, choice] = lines(fixture);
    expect(greeting.querySelector('time')!.getAttribute('datetime')).toBe('2026-09-29T09:50:00Z');
    expect(choice.querySelector('time')!.getAttribute('datetime')).toBe('2026-09-29T09:51:00Z');
  });

  it('shows the date on the first line of each day and only the time on the others', async () => {
    chatbotConversation.mockReturnValue(
      of(
        aChatbotTranscript({
          messages: [
            aChatbotMessage({ id: 1, createdAt: '2026-09-29T12:00:00Z' }),
            aChatbotMessage({ id: 2, sender: 'USER', createdAt: '2026-09-29T12:05:00Z' }),
            aChatbotMessage({ id: 3, createdAt: '2026-09-30T12:00:00Z' }),
          ],
        }),
      ),
    );
    const fixture = await render();

    const [first, sameDay, nextDay] = lines(fixture);
    expect(part(first, 'time')).toBe(formatDateTime('2026-09-29T12:00:00Z'));
    expect(part(sameDay, 'time')).toBe(formatTime('2026-09-29T12:05:00Z'));
    expect(part(nextDay, 'time')).toBe(formatDateTime('2026-09-30T12:00:00Z'));
  });

  it('hides the whole block when the ticket has no conversation (404)', async () => {
    chatbotConversation.mockReturnValue(
      throwError(() => httpError(404, 'Conversa não encontrada.')),
    );
    const fixture = await render();

    expect(fixture.nativeElement.querySelector('section')).toBeNull();
    expect(fixture.nativeElement.textContent.trim()).toBe('');
  });

  it('shows the error with Tentar de novo, and loads again on click', async () => {
    chatbotConversation.mockReturnValueOnce(throwError(() => httpError(500)));
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Não foi possível carregar a conversa.');
    expect(lines(fixture)).toHaveLength(0);

    retryButton(fixture)!.click();
    await fixture.whenStable();

    expect(chatbotConversation).toHaveBeenCalledTimes(2);
    expect(fixture.nativeElement.textContent).not.toContain(
      'Não foi possível carregar a conversa.',
    );
    expect(retryButton(fixture)).toBeUndefined();
    expect(lines(fixture)).toHaveLength(3);
  });

  it('treats a network failure as an error, not as a missing conversation', async () => {
    chatbotConversation.mockReturnValue(throwError(() => httpError(0)));
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Não foi possível carregar a conversa.');
    expect(retryButton(fixture)).toBeDefined();
  });

  it('shows HTML typed by the user as text', async () => {
    chatbotConversation.mockReturnValue(
      of(
        aChatbotTranscript({
          messages: [aChatbotMessage({ sender: 'USER', body: 'Meu <b>pedido</b>\nnão chegou' })],
        }),
      ),
    );
    const fixture = await render();

    const body = lines(fixture)[0].querySelector('p')!;
    expect(body.textContent).toBe('Meu <b>pedido</b>\nnão chegou');
    expect(body.querySelector('b')).toBeNull();
  });

  it('loads the conversation of the new ticket when the id changes', async () => {
    const fixture = await render(12);
    chatbotConversation.mockReturnValue(
      of(aChatbotTranscript({ conversationId: 43, messages: [aChatbotMessage({ body: 'Oi' })] })),
    );

    fixture.componentRef.setInput('ticketId', 13);
    await fixture.whenStable();

    expect(chatbotConversation).toHaveBeenLastCalledWith(13);
    expect(lines(fixture)).toHaveLength(1);
    expect(part(lines(fixture)[0], 'p')).toBe('Oi');
  });
});
