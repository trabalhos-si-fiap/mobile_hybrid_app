import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NEVER, of } from 'rxjs';

import { TicketDetail } from '../../../core/models/ticket.model';
import { TicketService } from '../../../core/services/ticket.service';
import { formatDateTime } from '../../../core/utils/time-format';
import { aChatbotTranscript, anAttachment, aTicket, NOW } from '../../../testing/test-data';
import { TicketInfoPanelComponent } from './ticket-info-panel.component';

describe('TicketInfoPanelComponent', () => {
  let chatbotConversation: Mock;

  beforeEach(() => {
    chatbotConversation = vi.fn(() => of(aChatbotTranscript()));
    TestBed.configureTestingModule({
      providers: [
        {
          provide: TicketService,
          useValue: { downloadAttachment: () => NEVER, chatbotConversation },
        },
      ],
    });
  });

  async function render(ticket: TicketDetail): Promise<ComponentFixture<TicketInfoPanelComponent>> {
    const fixture = TestBed.createComponent(TicketInfoPanelComponent);
    fixture.componentRef.setInput('ticket', ticket);
    fixture.componentRef.setInput('events', []);
    fixture.componentRef.setInput('now', NOW);
    await fixture.whenStable();
    return fixture;
  }

  function text(fixture: ComponentFixture<TicketInfoPanelComponent>): string {
    return fixture.nativeElement.textContent;
  }

  function headings(fixture: ComponentFixture<TicketInfoPanelComponent>): string[] {
    return Array.from<HTMLElement>(fixture.nativeElement.querySelectorAll('h2')).map((heading) =>
      heading.textContent!.trim(),
    );
  }

  it('shows the requester and the service data', async () => {
    const fixture = await render(aTicket());

    expect(text(fixture)).toContain('Ana Usuária');
    expect(text(fixture)).toContain('ana@edu.com');
    expect(text(fixture)).toContain('Defeito no App / Problemas com App');
    expect(text(fixture)).toContain('Tecnologia');
    expect(text(fixture)).toContain('App');
    expect(text(fixture)).toContain('Diego Dev');
  });

  it('labels the bot channel as Chatbot', async () => {
    const fixture = await render(aTicket({ channel: 'CHATBOT_IA' }));

    const channel = fixture.nativeElement.querySelector('[data-field="channel"]');
    expect(channel.textContent.trim()).toBe('Chatbot');
  });

  it('shows only the dates that exist', async () => {
    const fixture = await render(aTicket());

    expect(text(fixture)).toContain('Aberto em');
    expect(text(fixture)).toContain(formatDateTime('2026-09-29T10:00:00Z'));
    expect(text(fixture)).toContain('Assumido em');
    expect(text(fixture)).not.toContain('Resolvido em');
    expect(text(fixture)).not.toContain('Fechado em');
  });

  it('shows a dash when nobody has the ticket', async () => {
    const fixture = await render(aTicket({ status: 'EM_FILA', assignee: null, assumedAt: null }));

    const assignee = fixture.nativeElement.querySelector('[data-field="assignee"]');
    expect(assignee.textContent.trim()).toBe('—');
  });

  it('shows the SLA with absolute and relative deadline', async () => {
    const fixture = await render(aTicket());

    expect(text(fixture)).toContain('No prazo');
    expect(text(fixture)).toContain(formatDateTime('2026-09-29T14:00:00Z'));
    expect(text(fixture)).toContain('vence em 2 horas');
  });

  it('shows the engineering alert block only when marked', async () => {
    const plain = await render(aTicket());
    expect(plain.nativeElement.querySelector('.block-alert')).toBeNull();

    plain.componentRef.setInput(
      'ticket',
      aTicket({ engineeringAlert: true, engineeringAlertReason: 'Crash no checkout' }),
    );
    await plain.whenStable();

    expect(plain.nativeElement.querySelector('.block-alert').textContent).toContain(
      'Crash no checkout',
    );
  });

  it('keeps the line breaks of the description as text', async () => {
    const fixture = await render(aTicket({ description: 'Linha 1\nLinha 2 <b>sem negrito</b>' }));

    const description: HTMLElement = fixture.nativeElement.querySelector('.description');
    expect(description.textContent).toBe('Linha 1\nLinha 2 <b>sem negrito</b>');
    expect(description.querySelector('b')).toBeNull();
  });

  it('lists the opening attachments', async () => {
    const fixture = await render(
      aTicket({
        attachments: [
          anAttachment(),
          anAttachment({ id: 4, fileName: 'b.pdf', contentType: 'application/pdf' }),
        ],
      }),
    );

    expect(fixture.nativeElement.querySelectorAll('app-attachment-view')).toHaveLength(2);
  });

  it('shows the chatbot conversation between the service data and the description', async () => {
    const fixture = await render(aTicket({ channel: 'CHATBOT_IA' }));

    const order = headings(fixture);
    const transcript = order.indexOf('Conversa com o chatbot');
    expect(transcript).toBeGreaterThan(order.indexOf('Atendimento'));
    expect(transcript).toBe(order.indexOf('Descrição') - 1);
    expect(chatbotConversation).toHaveBeenCalledWith(12);
    const userLine: HTMLElement = fixture.nativeElement.querySelector('li[data-sender="USER"]');
    expect(userLine.querySelector('strong')!.textContent).toBe('Ana Usuária');
  });

  it('has no chatbot block, and asks for nothing, on an APP ticket', async () => {
    const fixture = await render(aTicket());

    expect(fixture.nativeElement.querySelector('app-ticket-chatbot-transcript')).toBeNull();
    expect(headings(fixture)).not.toContain('Conversa com o chatbot');
    expect(chatbotConversation).not.toHaveBeenCalled();
  });

  it('loads the conversation once while the detail polling replaces the ticket', async () => {
    const fixture = await render(aTicket({ channel: 'CHATBOT_IA' }));

    fixture.componentRef.setInput(
      'ticket',
      aTicket({ channel: 'CHATBOT_IA', status: 'RESOLVIDO' }),
    );
    await fixture.whenStable();
    fixture.componentRef.setInput('ticket', aTicket({ channel: 'CHATBOT_IA', status: 'FECHADO' }));
    await fixture.whenStable();

    expect(chatbotConversation).toHaveBeenCalledTimes(1);
    expect(fixture.nativeElement.querySelectorAll('li[data-sender]')).toHaveLength(3);
  });
});
