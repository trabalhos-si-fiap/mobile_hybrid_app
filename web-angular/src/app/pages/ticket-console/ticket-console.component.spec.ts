import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { ActivatedRoute, convertToParamMap, ParamMap, provideRouter, Router } from '@angular/router';
import { BehaviorSubject, NEVER, of, Subject, throwError } from 'rxjs';

import { EmployeeMe, TicketDetail } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { FlashMessageService } from '../../core/services/flash-message.service';
import { TicketService } from '../../core/services/ticket.service';
import { aMessage, anEmployee, aTicket, httpError, SEGMENTS } from '../../testing/test-data';
import { TicketActionsBarComponent } from './ticket-actions-bar/ticket-actions-bar.component';
import { TicketChatComponent } from './ticket-chat/ticket-chat.component';
import { TicketConsoleComponent } from './ticket-console.component';

describe('TicketConsoleComponent', () => {
  let tickets: Record<string, Mock>;
  let params: BehaviorSubject<ParamMap>;
  let userId: number;
  let router: Router;

  beforeEach(() => {
    tickets = {
      get: vi.fn((id: number) => of(aTicket({ id }))),
      events: vi.fn(() => of([])),
      messages: vi.fn(() => of([aMessage()])),
      assume: vi.fn(() => of(aTicket())),
      resolve: vi.fn(() => of(aTicket({ status: 'RESOLVIDO' }))),
      sendMessage: vi.fn(),
      segments: vi.fn(() => of(SEGMENTS)),
      transfer: vi.fn(),
      raiseEngineeringAlert: vi.fn(),
      downloadAttachment: vi.fn(() => NEVER)
    };
    params = new BehaviorSubject(convertToParamMap({ id: '12' }));
    userId = 20;
  });

  async function render(me: EmployeeMe | null = anEmployee()): Promise<ComponentFixture<TicketConsoleComponent>> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { paramMap: params } },
        { provide: TicketService, useValue: tickets },
        { provide: EmployeeService, useValue: { me: signal(me) } },
        {
          provide: AuthService,
          useValue: {
            isAdmin: () => false,
            currentUser: () => ({ id: userId, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' })
          }
        }
      ]
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);

    const fixture = TestBed.createComponent(TicketConsoleComponent);
    await fixture.whenStable();
    return fixture;
  }

  function text(fixture: ComponentFixture<TicketConsoleComponent>): string {
    return fixture.nativeElement.textContent;
  }

  function header(fixture: ComponentFixture<TicketConsoleComponent>): HTMLElement {
    return fixture.nativeElement.querySelector('.console-header');
  }

  function actionLabels(fixture: ComponentFixture<TicketConsoleComponent>): string[] {
    return Array.from<HTMLButtonElement>(
      fixture.nativeElement.querySelectorAll('[role="toolbar"] button')
    ).map(button => button.textContent!.trim());
  }

  it('loads the ticket, its events and its messages for the route id', async () => {
    const fixture = await render();

    expect(tickets['get']).toHaveBeenCalledWith(12);
    expect(tickets['events']).toHaveBeenCalledWith(12);
    expect(tickets['messages']).toHaveBeenCalledWith(12);
    expect(header(fixture).textContent).toContain('#12 · Defeito no App / Problemas com App');
    expect(header(fixture).textContent).toContain('Em atendimento');
    expect(header(fixture).textContent).toContain('Alta');
    expect(text(fixture)).toContain('Oi, o app travou de novo.');
  });

  it('shows the owner only the allowed actions and an open chat', async () => {
    const fixture = await render();

    expect(actionLabels(fixture)).toEqual(['Encerrar', 'Transferir', 'Alertar engenharia']);
    expect(fixture.nativeElement.querySelector('textarea[aria-label="Mensagem"]')).not.toBeNull();
  });

  it('offers Assumir on a waiting ticket and locks the chat', async () => {
    tickets['get'].mockReturnValue(of(aTicket({ status: 'EM_FILA', assignee: null })));
    const fixture = await render();

    expect(actionLabels(fixture)).toEqual(['Assumir']);
    expect(text(fixture)).toContain('Assuma o ticket para responder.');
  });

  it('hides every action from the requester', async () => {
    userId = 50;
    const fixture = await render();

    expect(fixture.nativeElement.querySelector('[role="toolbar"]')).toBeNull();
    expect(text(fixture)).toContain('Você abriu este ticket. Responda pelo app Edu.');
  });

  it('assumes, shows the new state and reloads', async () => {
    tickets['get'].mockReturnValue(of(aTicket({ status: 'EM_FILA', assignee: null })));
    const fixture = await render();
    tickets['get'].mockReturnValue(of(aTicket()));

    fixture.componentInstance.assume();
    await fixture.whenStable();

    expect(tickets['assume']).toHaveBeenCalledWith(12);
    expect(tickets['get']).toHaveBeenCalledTimes(2);
    expect(header(fixture).textContent).toContain('Em atendimento');
    expect(text(fixture)).toContain('Ticket assumido.');
  });

  it('shows the API message and reloads on a 409', async () => {
    tickets['resolve'].mockReturnValue(
      throwError(() => httpError(409, 'Não é possível encerrar o ticket 12 no estado EM_FILA'))
    );
    const fixture = await render();

    fixture.componentInstance.resolve();
    await fixture.whenStable();

    expect(text(fixture)).toContain('Não é possível encerrar o ticket 12 no estado EM_FILA');
    expect(tickets['get']).toHaveBeenCalledTimes(2);
    expect(tickets['messages']).toHaveBeenCalledTimes(2);
  });

  it('shows the not-found page on a 404 and stops polling', async () => {
    tickets['get'].mockReturnValue(throwError(() => httpError(404, 'Ticket 12 não encontrado')));
    const fixture = await render();

    expect(text(fixture)).toContain('Ticket não encontrado ou sem acesso');
    expect(fixture.nativeElement.querySelector('a[href="/atendimento"]')).not.toBeNull();

    const messageCalls = tickets['messages'].mock.calls.length;
    fixture.componentInstance.reloadAll();
    expect(tickets['messages']).toHaveBeenCalledTimes(messageCalls);
  });

  it('treats an id that is not a number as not found, without calling the API', async () => {
    params.next(convertToParamMap({ id: 'abc' }));
    const fixture = await render();

    expect(tickets['get']).not.toHaveBeenCalled();
    expect(text(fixture)).toContain('Ticket não encontrado ou sem acesso');
  });

  it('switching to another ticket drops the old one and loads the new', async () => {
    const fixture = await render();
    tickets['get'].mockImplementation((id: number) => (id === 13 ? NEVER : of(aTicket({ id }))));

    params.next(convertToParamMap({ id: '13' }));
    await fixture.whenStable();

    expect(tickets['get']).toHaveBeenLastCalledWith(13);
    expect(header(fixture)).toBeNull();
    expect(text(fixture)).toContain('Carregando ticket...');

    tickets['get'].mockClear();
    fixture.componentInstance.reloadAll();
    expect(tickets['get']).not.toHaveBeenCalledWith(12);
  });

  it('ignores a late action response from the previous ticket', async () => {
    const late = new Subject<TicketDetail>();
    tickets['assume'].mockReturnValue(late);
    const fixture = await render();

    fixture.componentInstance.assume();
    params.next(convertToParamMap({ id: '13' }));
    await fixture.whenStable();
    late.next(aTicket({ id: 12 }));
    await fixture.whenStable();

    expect(header(fixture).textContent).toContain('#13');
    expect(header(fixture).textContent).not.toContain('#12');
    expect(text(fixture)).not.toContain('Ticket assumido.');

    tickets['resolve'].mockReturnValue(of(aTicket({ id: 13, status: 'RESOLVIDO' })));
    fixture.componentInstance.resolve();
    await fixture.whenStable();
    expect(tickets['resolve']).toHaveBeenCalledWith(13);
  });

  it('keeps the data and shows the offline marker when polling fails', async () => {
    const fixture = await render();
    tickets['get'].mockReturnValue(throwError(() => httpError(503)));

    fixture.componentInstance.reloadAll();
    await fixture.whenStable();

    expect(text(fixture)).toContain('Sem conexão — tentando de novo');
    expect(header(fixture).textContent).toContain('#12');
  });

  it('goes back to the queue with a notice after a transfer', async () => {
    const fixture = await render();
    const bar = fixture.debugElement.query(By.directive(TicketActionsBarComponent));

    bar.componentInstance.transferred.emit({
      ticket: aTicket({ segment: 'FEEDBACK_SUGESTAO' }),
      label: 'Feedback / Sugestões'
    });

    expect(TestBed.inject(FlashMessageService).take()).toBe(
      'Ticket #12 transferido para Feedback / Sugestões'
    );
    expect(router.navigate).toHaveBeenCalledWith(['/atendimento']);
  });

  it('reloads the messages after one is sent', async () => {
    const fixture = await render();
    const chat = fixture.debugElement.query(By.directive(TicketChatComponent));

    chat.componentInstance.sent.emit(aMessage({ id: 101 }));

    expect(tickets['messages']).toHaveBeenCalledTimes(2);
  });

  it('shows the alert badge after the engineering alert', async () => {
    const fixture = await render();
    const alerted: TicketDetail = aTicket({ engineeringAlert: true, engineeringAlertReason: 'Crash' });
    tickets['get'].mockReturnValue(of(alerted));

    fixture.componentInstance.alertRaised(alerted);
    await fixture.whenStable();

    expect(header(fixture).textContent).toContain('Alerta de engenharia');
    expect(text(fixture)).toContain('Alerta enviado à engenharia.');
  });
});
