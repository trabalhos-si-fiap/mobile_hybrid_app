import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { signal, WritableSignal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { EmployeeMe } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { anEmployee, httpError } from '../../testing/test-data';
import { AgentCardComponent } from './agent-card.component';

describe('AgentCardComponent', () => {
  let me: WritableSignal<EmployeeMe | null | undefined>;
  let changePresence: Mock;

  beforeEach(() => {
    me = signal<EmployeeMe | null | undefined>(anEmployee({ presence: 'OFFLINE' }));
    changePresence = vi.fn((presence: string) => {
      me.set(anEmployee({ presence: presence as EmployeeMe['presence'] }));
      return of(me());
    });
    TestBed.configureTestingModule({
      providers: [
        { provide: EmployeeService, useValue: { me, changePresence } },
        {
          provide: AuthService,
          useValue: {
            currentUser: () => ({ id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' })
          }
        }
      ]
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

  async function choose(fixture: ComponentFixture<AgentCardComponent>, value: string): Promise<void> {
    select(fixture).value = value;
    select(fixture).dispatchEvent(new Event('change'));
    await fixture.whenStable();
  }

  it('shows the agent with skills and the current presence', async () => {
    const fixture = await render();

    const card: HTMLElement = fixture.nativeElement.querySelector('section[aria-label="Atendente"]');
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
  });
});
