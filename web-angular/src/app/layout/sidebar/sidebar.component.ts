import { Component, inject, signal } from '@angular/core';
import { Router, RouterLink, RouterLinkActive } from '@angular/router';
import { of } from 'rxjs';

import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { NotificationService } from '../../core/services/notification.service';
import { AgentCardComponent } from '../agent-card/agent-card.component';

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, AgentCardComponent],
  templateUrl: './sidebar.component.html',
  styleUrl: './sidebar.component.scss'
})
export class SidebarComponent {
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);
  private readonly notifications = inject(NotificationService);
  private readonly router = inject(Router);

  readonly leaving = signal(false);

  /** Atendente sai OFFLINE (no máximo 3 s de espera) para não receber tickets depois de sair. */
  logout(): void {
    if (this.leaving()) {
      return;
    }
    this.leaving.set(true);

    const offline$ = this.employees.me() ? this.employees.goOffline() : of(undefined);

    offline$.subscribe(() => {
      this.auth.logout();
      this.employees.clear();
      this.notifications.clear();
      this.router.navigateByUrl('/login');
    });
  }
}
