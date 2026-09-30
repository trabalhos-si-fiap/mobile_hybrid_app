import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NEVER, of, Subject, throwError } from 'rxjs';

import { TicketMessage } from '../../../core/models/ticket.model';
import { TicketService } from '../../../core/services/ticket.service';
import { aMessage, fakeFile, httpError } from '../../../testing/test-data';
import { TicketChatComponent } from './ticket-chat.component';

describe('TicketChatComponent', () => {
  let sendMessage: Mock;

  beforeEach(() => {
    sendMessage = vi.fn(() => of(aMessage({ id: 101, senderType: 'EMPLOYEE' })));
    TestBed.configureTestingModule({
      providers: [
        { provide: TicketService, useValue: { sendMessage, downloadAttachment: () => NEVER } }
      ]
    });
  });

  async function render(
    messages: TicketMessage[] = [aMessage()],
    blockReason: string | null = null
  ): Promise<{ fixture: ComponentFixture<TicketChatComponent>; sent: Mock; failed: Mock }> {
    const fixture = TestBed.createComponent(TicketChatComponent);
    fixture.componentRef.setInput('ticketId', 12);
    fixture.componentRef.setInput('messages', messages);
    fixture.componentRef.setInput('blockReason', blockReason);
    const sent = vi.fn();
    const failed = vi.fn();
    fixture.componentInstance.sent.subscribe(sent);
    fixture.componentInstance.failed.subscribe(failed);
    await fixture.whenStable();
    return { fixture, sent, failed };
  }

  function textarea(fixture: ComponentFixture<TicketChatComponent>): HTMLTextAreaElement {
    return fixture.nativeElement.querySelector('textarea[aria-label="Mensagem"]');
  }

  async function type(fixture: ComponentFixture<TicketChatComponent>, value: string): Promise<void> {
    textarea(fixture).value = value;
    textarea(fixture).dispatchEvent(new Event('input'));
    await fixture.whenStable();
  }

  async function pick(fixture: ComponentFixture<TicketChatComponent>, files: File[]): Promise<HTMLInputElement> {
    const input: HTMLInputElement = fixture.nativeElement.querySelector('input[type="file"]');
    Object.defineProperty(input, 'files', { value: files, configurable: true });
    input.dispatchEvent(new Event('change'));
    await fixture.whenStable();
    return input;
  }

  function sendButton(fixture: ComponentFixture<TicketChatComponent>): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button[type="submit"]');
  }

  async function send(fixture: ComponentFixture<TicketChatComponent>): Promise<void> {
    sendButton(fixture).click();
    await fixture.whenStable();
  }

  it('places messages by sender', async () => {
    const { fixture } = await render([
      aMessage({ id: 1, senderType: 'USER' }),
      aMessage({ id: 2, senderType: 'EMPLOYEE', senderName: 'Diego Dev' }),
      aMessage({ id: 3, senderType: 'SYSTEM', senderName: 'Sistema' })
    ]);

    const senders = Array.from<HTMLElement>(fixture.nativeElement.querySelectorAll('.message')).map(
      message => message.getAttribute('data-sender')
    );
    expect(senders).toEqual(['USER', 'EMPLOYEE', 'SYSTEM']);
    expect(fixture.nativeElement.textContent).toContain('Oi, o app travou de novo.');
  });

  it('shows HTML typed by the user as text', async () => {
    const { fixture } = await render([aMessage({ body: '<img src=x onerror=alert(1)>' })]);

    const body: HTMLElement = fixture.nativeElement.querySelector('.message p');
    expect(body.textContent).toBe('<img src=x onerror=alert(1)>');
    expect(body.querySelector('img')).toBeNull();
  });

  it('swaps the composer for the block reason', async () => {
    const { fixture } = await render([], 'Assuma o ticket para responder.');

    expect(textarea(fixture)).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Assuma o ticket para responder.');
  });

  it('sends the trimmed text with the files and clears the composer', async () => {
    const { fixture, sent } = await render();
    const file = fakeFile('print.png', 'image/png', 1024);

    await type(fixture, '  Pode mandar a versão?  ');
    await pick(fixture, [file]);
    await send(fixture);

    expect(sendMessage).toHaveBeenCalledWith(12, 'Pode mandar a versão?', [file]);
    expect(sent).toHaveBeenCalled();
    expect(textarea(fixture).value).toBe('');
    expect(fixture.nativeElement.querySelector('.picked')).toBeNull();
  });

  it('sends on Enter and breaks the line on Shift+Enter', async () => {
    const { fixture } = await render();
    await type(fixture, 'Olá');

    textarea(fixture).dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', shiftKey: true }));
    expect(sendMessage).not.toHaveBeenCalled();

    textarea(fixture).dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', cancelable: true }));
    expect(sendMessage).toHaveBeenCalledTimes(1);
  });

  it('does not send a blank message', async () => {
    const { fixture } = await render();
    await type(fixture, '   \n ');

    await send(fixture);

    expect(sendMessage).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Escreva uma mensagem.');
  });

  it('sends only once on a double submit', async () => {
    sendMessage.mockReturnValue(new Subject());
    const { fixture } = await render();
    await type(fixture, 'Olá');

    sendButton(fixture).click();
    sendButton(fixture).click();

    expect(sendMessage).toHaveBeenCalledTimes(1);
  });

  it('keeps text and files and shows the API message on a 400', async () => {
    sendMessage.mockReturnValue(throwError(() => httpError(400, 'Arquivo vazio: print.png')));
    const { fixture, failed } = await render();
    await type(fixture, 'Segue o print');
    await pick(fixture, [fakeFile('print.png', 'image/png', 1024)]);

    await send(fixture);

    expect(fixture.nativeElement.textContent).toContain('Arquivo vazio: print.png');
    expect(textarea(fixture).value).toBe('Segue o print');
    expect(fixture.nativeElement.querySelector('.picked').textContent).toContain('print.png');
    expect(failed).not.toHaveBeenCalled();
  });

  it('hands other failures to the console and keeps the text', async () => {
    const conflict = httpError(409, 'Não é possível responder o ticket 12 no estado RESOLVIDO');
    sendMessage.mockReturnValue(throwError(() => conflict));
    const { fixture, failed } = await render();
    await type(fixture, 'Olá');

    await send(fixture);

    expect(failed).toHaveBeenCalledWith(conflict);
    expect(textarea(fixture).value).toBe('Olá');
  });

  it('refuses the sixth file and resets the picker', async () => {
    const { fixture } = await render();
    const six = [1, 2, 3, 4, 5, 6].map(i => fakeFile(`${i}.png`, 'image/png', 10));

    const input = await pick(fixture, six);

    expect(fixture.nativeElement.querySelectorAll('.picked li')).toHaveLength(5);
    expect(fixture.nativeElement.textContent).toContain('Anexe no máximo 5 arquivos por mensagem.');
    expect(input.value).toBe('');
  });

  it('removes a chosen file', async () => {
    const { fixture } = await render();
    await pick(fixture, [fakeFile('a.png', 'image/png', 10), fakeFile('b.png', 'image/png', 10)]);

    fixture.nativeElement.querySelector('button[aria-label="Remover a.png"]').click();
    await fixture.whenStable();

    const names = fixture.nativeElement.querySelector('.picked').textContent;
    expect(names).not.toContain('a.png');
    expect(names).toContain('b.png');
  });

  it('counts the characters', async () => {
    const { fixture } = await render();

    await type(fixture, 'Olá');

    expect(fixture.nativeElement.querySelector('.counter').textContent.trim()).toBe('3/2000');
  });
});
