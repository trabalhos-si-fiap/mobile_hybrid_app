import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { signal, WritableSignal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter, Router } from '@angular/router';
import { BehaviorSubject, of, Subject, throwError } from 'rxjs';

import { EmployeeMe, Presence, TicketSummary } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { FlashMessageService } from '../../core/services/flash-message.service';
import { TicketService } from '../../core/services/ticket.service';
import { anEmployee, aSummary, aTicket, httpError } from '../../testing/test-data';
import { AttendanceQueueComponent } from './attendance-queue.component';

describe('AttendanceQueueComponent', () => {
  let queue: Mock;
  let assume: Mock;
  let changePresence: Mock;
  let me: WritableSignal<EmployeeMe | null | undefined>;
  let presenceChanged: Subject<Presence>;
  let admin: boolean;
  let router: Router;

  beforeEach(() => {
    queue = vi.fn(() => of([aSummary()]));
    assume = vi.fn(() => of(aTicket()));
    changePresence = vi.fn(() => of(anEmployee()));
    me = signal<EmployeeMe | null | undefined>(anEmployee());
    presenceChanged = new Subject<Presence>();
    admin = false;
  });

  async function render(
    params: Record<string, string> = {},
    notice?: string,
  ): Promise<ComponentFixture<AttendanceQueueComponent>> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: { queryParamMap: new BehaviorSubject(convertToParamMap(params)) },
        },
        { provide: TicketService, useValue: { queue, assume } },
        {
          provide: EmployeeService,
          useValue: { me, presenceChanged$: presenceChanged, changePresence },
        },
        {
          provide: AuthService,
          useValue: {
            isAdmin: () => admin,
            currentUser: () => ({
              id: 20,
              name: 'Diego Dev',
              email: 'dev@edu.com',
              role: admin ? 'ADMIN' : 'EMPLOYEE',
            }),
          },
        },
      ],
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
    if (notice) {
      TestBed.inject(FlashMessageService).set(notice);
    }

    const fixture = TestBed.createComponent(AttendanceQueueComponent);
    await fixture.whenStable();
    return fixture;
  }

  function text(fixture: ComponentFixture<AttendanceQueueComponent>): string {
    return fixture.nativeElement.textContent;
  }

  function tabs(fixture: ComponentFixture<AttendanceQueueComponent>): string[] {
    return Array.from<HTMLElement>(fixture.nativeElement.querySelectorAll('[role="tab"]')).map(
      (tab) => tab.textContent!.trim(),
    );
  }

  function button(root: HTMLElement, label: string): HTMLButtonElement | undefined {
    return Array.from(root.querySelectorAll('button')).find(
      (item) => item.textContent?.trim() === label,
    );
  }

  function row(fixture: ComponentFixture<AttendanceQueueComponent>, id: number): HTMLElement {
    return fixture.nativeElement.querySelector(`tr[data-ticket-id="${id}"]`);
  }

  it('shows my queue and my skills to an agent, without Todos', async () => {
    const fixture = await render();

    expect(tabs(fixture)).toEqual(['Minha fila', 'Filas das minhas skills']);
    expect(queue).toHaveBeenCalledWith('mine', null);
  });

  it('adds Todos for ADMIN', async () => {
    admin = true;
    const fixture = await render();

    expect(tabs(fixture)).toEqual(['Minha fila', 'Filas das minhas skills', 'Todos']);
  });

  it('gives staff without an agent record only Todos, if ADMIN, and a warning', async () => {
    admin = true;
    me.set(null);
    const fixture = await render();

    expect(tabs(fixture)).toEqual(['Todos']);
    expect(text(fixture)).toContain('Sua conta não está cadastrada como atendente');
    expect(queue).toHaveBeenCalledWith('all', null);
  });

  it('shows no queue to staff without an agent record who is not ADMIN', async () => {
    me.set(null);
    const fixture = await render();

    expect(tabs(fixture)).toEqual([]);
    expect(text(fixture)).toContain('Sua conta não está cadastrada como atendente');
    expect(queue).not.toHaveBeenCalled();
  });

  it('reads the tab and the status from the URL', async () => {
    const fixture = await render({ aba: 'skills', status: 'EM_FILA' });

    expect(queue).toHaveBeenCalledWith('skills', 'EM_FILA');
    const select: HTMLSelectElement = fixture.nativeElement.querySelector('select');
    expect(select.value).toBe('EM_FILA');
  });

  it('ignores a status the tab does not accept and a tab the profile cannot see', async () => {
    await render({ aba: 'todos', status: 'ABERTO' });

    expect(queue).toHaveBeenCalledWith('mine', null);
  });

  it('writes the chosen tab and status to the URL', async () => {
    const fixture = await render();

    button(fixture.nativeElement, 'Filas das minhas skills')!.click();
    expect(router.navigate).toHaveBeenCalledWith(
      [],
      expect.objectContaining({ queryParams: { aba: 'skills' } }),
    );

    const select: HTMLSelectElement = fixture.nativeElement.querySelector('select');
    select.value = 'RESOLVIDO';
    select.dispatchEvent(new Event('change'));
    expect(router.navigate).toHaveBeenCalledWith(
      [],
      expect.objectContaining({ queryParams: { aba: 'minha', status: 'RESOLVIDO' } }),
    );
  });

  it('renders the row with its columns', async () => {
    queue.mockReturnValue(of([aSummary({ engineeringAlert: true })]));
    const fixture = await render();

    const line = row(fixture, 12);
    expect(line.textContent).toContain('#12');
    expect(line.textContent).toContain('Defeito no App / Problemas com App');
    expect(line.textContent).toContain('Alta');
    expect(line.textContent).toContain('Em fila');
    expect(line.textContent).toContain('No prazo');
    expect(line.textContent).toContain('Ana Usuária');
    expect(line.textContent).toContain('Diego Dev');
    expect(line.querySelector('[aria-label="Alerta de engenharia"]')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('table').getAttribute('aria-busy')).toBe('false');
  });

  it('Atender assumes and opens the console', async () => {
    const fixture = await render();

    button(row(fixture, 12), 'Atender')!.click();

    expect(assume).toHaveBeenCalledWith(12);
    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('ignores a second Atender while the first is running', async () => {
    assume.mockReturnValue(new Subject());
    const fixture = await render();

    button(row(fixture, 12), 'Atender')!.click();
    button(row(fixture, 12), 'Atender')!.click();

    expect(assume).toHaveBeenCalledTimes(1);
  });

  it('shows the API message and reloads on a 409', async () => {
    assume.mockReturnValue(
      throwError(() => httpError(409, 'Ticket 12 está atribuído a outro atendente')),
    );
    const fixture = await render();

    button(row(fixture, 12), 'Atender')!.click();
    await fixture.whenStable();

    expect(text(fixture)).toContain('Ticket 12 está atribuído a outro atendente');
    expect(queue).toHaveBeenCalledTimes(2);
    expect(router.navigate).not.toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('only offers Abrir for a ticket of someone else in the skills tab', async () => {
    queue.mockReturnValue(of([aSummary({ assigneeName: 'Rita' })]));
    const fixture = await render({ aba: 'skills' });

    expect(button(row(fixture, 12), 'Atender')).toBeUndefined();
    button(row(fixture, 12), 'Abrir')!.click();

    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('opens the console when the row is clicked', async () => {
    const fixture = await render();

    row(fixture, 12).click();

    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('opens from the keyboard only when the row itself has focus', async () => {
    const fixture = await render();
    const enter = () => new KeyboardEvent('keydown', { key: 'Enter', bubbles: true });

    button(row(fixture, 12), 'Atender')!.dispatchEvent(enter());
    expect(router.navigate).not.toHaveBeenCalledWith(['/atendimento', 12]);
    expect(assume).not.toHaveBeenCalled();

    row(fixture, 12).dispatchEvent(enter());
    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('warns an agent who is not Online and goes Online on click', async () => {
    me.set(anEmployee({ presence: 'OFFLINE' }));
    const fixture = await render();

    expect(text(fixture)).toContain('Você está Offline e não recebe tickets novos');
    button(fixture.nativeElement, 'Ficar Online')!.click();

    expect(changePresence).toHaveBeenCalledWith('ONLINE');
  });

  it('reloads at once when the presence changes', async () => {
    await render();

    presenceChanged.next('ONLINE');

    expect(queue).toHaveBeenCalledTimes(2);
  });

  it('has its own message for an empty tab', async () => {
    queue.mockReturnValue(of([] as TicketSummary[]));
    const fixture = await render();

    expect(text(fixture)).toContain('Nenhum ticket na sua fila.');
  });

  it('keeps the rows and shows the offline marker when polling fails', async () => {
    const fixture = await render();
    queue.mockReturnValue(throwError(() => httpError(503)));

    presenceChanged.next('ONLINE');
    await fixture.whenStable();

    expect(text(fixture)).toContain('Sem conexão — tentando de novo');
    expect(row(fixture, 12)).not.toBeNull();
  });

  it('shows the notice left by the console as a toast', async () => {
    const fixture = await render({}, 'Ticket #12 transferido para Feedback / Sugestões');

    expect(text(fixture)).toContain('Ticket #12 transferido para Feedback / Sugestões');
  });
});
