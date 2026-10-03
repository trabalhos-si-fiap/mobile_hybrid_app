import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { Component, signal, WritableSignal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router, RouterLink, RouterLinkActive } from '@angular/router';
import { of, Subject } from 'rxjs';

import { EmployeeMe } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { NotificationService } from '../../core/services/notification.service';
import { anEmployee } from '../../testing/test-data';
import { SidebarComponent } from './sidebar.component';

@Component({ selector: 'app-agent-card', standalone: true, template: '' })
class AgentCardStubComponent {}

describe('SidebarComponent', () => {
  let me: WritableSignal<EmployeeMe | null | undefined>;
  let goOffline: Mock;
  let logout: Mock;
  let router: Router;

  beforeEach(() => {
    me = signal<EmployeeMe | null | undefined>(anEmployee());
    goOffline = vi.fn(() => of(undefined));
    logout = vi.fn();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: EmployeeService, useValue: { me, goOffline, clear: vi.fn() } },
        { provide: NotificationService, useValue: { clear: vi.fn() } },
        { provide: AuthService, useValue: { logout } },
      ],
    });
    TestBed.overrideComponent(SidebarComponent, {
      set: { imports: [RouterLink, RouterLinkActive, AgentCardStubComponent] },
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigateByUrl').mockResolvedValue(true);
  });

  async function render(): Promise<ComponentFixture<SidebarComponent>> {
    const fixture = TestBed.createComponent(SidebarComponent);
    await fixture.whenStable();
    return fixture;
  }

  function logoutButton(fixture: ComponentFixture<SidebarComponent>): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button.logout');
  }

  it('links Atendimento right after Dashboard', async () => {
    const fixture = await render();

    const links = Array.from<HTMLAnchorElement>(
      fixture.nativeElement.querySelectorAll('a.nav-item'),
    );
    expect(links.map((link) => link.textContent?.trim())).toEqual([
      'Dashboard',
      'Atendimento',
      'Produtos e Estoque',
      'Transportadoras',
    ]);
    expect(links[1].getAttribute('href')).toBe('/atendimento');
  });

  it('goes OFFLINE before leaving and only then logs out', async () => {
    const offline = new Subject<void>();
    goOffline.mockReturnValue(offline);
    const fixture = await render();

    logoutButton(fixture).click();
    expect(goOffline).toHaveBeenCalled();
    expect(logout).not.toHaveBeenCalled();

    offline.next();
    offline.complete();

    expect(logout).toHaveBeenCalled();
    expect(router.navigateByUrl).toHaveBeenCalledWith('/login');
  });

  it('leaves at once when the account is not an agent', async () => {
    me.set(null);
    const fixture = await render();

    logoutButton(fixture).click();

    expect(goOffline).not.toHaveBeenCalled();
    expect(logout).toHaveBeenCalled();
    expect(router.navigateByUrl).toHaveBeenCalledWith('/login');
  });
});
