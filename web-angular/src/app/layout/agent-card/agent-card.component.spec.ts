import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { signal, WritableSignal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';

import { EmployeeMe } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { NotificationService } from '../../core/services/notification.service';
import { anEmployee, httpError } from '../../testing/test-data';
import { AgentCardComponent } from './agent-card.component';

describe('AgentCardComponent', () => {
  let me: WritableSignal<EmployeeMe | null | undefined>;
  let changePresence: Mock;
  let unreadCount: WritableSignal<number>;
  let refreshUnread: Mock;

  beforeEach(() => {
    me = signal<EmployeeMe | null | undefined>(anEmployee({ presence: 'OFFLINE' }));
    changePresence = vi.fn((presence: string) => {
      me.set(anEmployee({ presence: presence as EmployeeMe['presence'] }));
      return of(me());
    });
    unreadCount = signal(0);
    refreshUnread = vi.fn(() => of(unreadCount()));
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: EmployeeService, useValue: { me, changePresence } },
        {
          provide: NotificationService,
          useValue: {
            unreadCount,
            refreshUnread,
            list: () => of([]),
            markRead: () => of(undefined),
            markAllRead: () => of(undefined),
          },
        },
        {
          provide: AuthService,
          useValue: {
            currentUser: () => ({
              id: 20,
              name: 'Diego Dev',
              email: 'dev@edu.com',
              role: 'EMPLOYEE',
            }),
          },
        },
      ],
    });
  });

  async function render(): Promise<ComponentFixture<AgentCardComponent>> {
    const fixture = TestBed.createComponent(AgentCardComponent);
    await fixture.whenStable();
    return fixture;
  }

  function select(fixture: ComponentFixture<AgentCardComponent>): HTMLSelectElement {
    return fixture.nativeElement.querySelector('select[aria-label="Presença"]');
  }

  function bell(fixture: ComponentFixture<AgentCardComponent>): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button[aria-label="Notificações"]');
  }

  function counter(fixture: ComponentFixture<AgentCardComponent>): HTMLElement | null {
    return fixture.nativeElement.querySelector('[data-testid="unread-count"]');
  }

  async function choose(
    fixture: ComponentFixture<AgentCardComponent>,
    value: string,
  ): Promise<void> {
    select(fixture).value = value;
    select(fixture).dispatchEvent(new Event('change'));
    await fixture.whenStable();
  }

  it('shows the agent with skills and the current presence', async () => {
    const fixture = await render();

    const card: HTMLElement = fixture.nativeElement.querySelector(
      'section[aria-label="Atendente"]',
    );
    expect(card.textContent).toContain('Diego Dev');
    expect(card.textContent).toContain('DESENVOLVEDOR');
    expect(select(fixture).value).toBe('OFFLINE');
    expect(card.querySelector('.presence-dot')?.getAttribute('data-presence')).toBe('OFFLINE');
  });

  it('changes the presence', async () => {
    const fixture = await render();

    await choose(fixture, 'ONLINE');

    expect(changePresence).toHaveBeenCalledWith('ONLINE');
    expect(select(fixture).value).toBe('ONLINE');
  });

  it('puts the selector back and explains when the change fails', async () => {
    changePresence.mockReturnValue(throwError(() => httpError(500)));
    const fixture = await render();

    await choose(fixture, 'AUSENTE');

    expect(select(fixture).value).toBe('OFFLINE');
    expect(fixture.nativeElement.textContent).toContain('Não foi possível mudar a presença.');
  });

  it('shows only the name for staff without an agent record', async () => {
    me.set(null);
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Diego Dev');
    expect(fixture.nativeElement.textContent).toContain('Sem cadastro de atendente');
    expect(select(fixture)).toBeNull();
    expect(bell(fixture)).toBeNull();
  });

  it('fetches the unread count when it opens and shows it on the bell', async () => {
    unreadCount.set(3);
    const fixture = await render();

    expect(refreshUnread).toHaveBeenCalledTimes(1);
    expect(counter(fixture)?.textContent?.trim()).toBe('3');
  });

  it('shows 50+ at the API maximum and nothing without unread', async () => {
    const fixture = await render();
    expect(counter(fixture)).toBeNull();

    unreadCount.set(50);
    await fixture.whenStable();

    expect(counter(fixture)?.textContent?.trim()).toBe('50+');
  });

  it('opens and closes the panel from the bell', async () => {
    const fixture = await render();

    bell(fixture).click();
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-notification-panel')).not.toBeNull();

    bell(fixture).click();
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-notification-panel')).toBeNull();
  });
});
