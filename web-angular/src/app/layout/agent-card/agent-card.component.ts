import { Component, computed, inject, signal } from '@angular/core';

import { Presence } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { apiErrorMessage } from '../../core/utils/api-error';
import { formatTime } from '../../core/utils/time-format';

@Component({
  selector: 'app-agent-card',
  standalone: true,
  templateUrl: './agent-card.component.html',
  styleUrl: './agent-card.component.scss'
})
export class AgentCardComponent {
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);

  readonly me = this.employees.me;
  readonly userName = this.auth.currentUser()?.name ?? '';
  readonly saving = signal(false);
  readonly error = signal('');
  readonly since = computed(() => formatTime(this.me()?.presenceChangedAt));

  /** Recebe o próprio select para devolvê-lo ao valor anterior se a API recusar. */
  changePresence(select: HTMLSelectElement): void {
    const previous = this.me()?.presence;
    const next = select.value as Presence;

    if (!previous || next === previous || this.saving()) {
      return;
    }

    this.saving.set(true);
    this.error.set('');

    this.employees.changePresence(next).subscribe({
      next: () => this.saving.set(false),
      error: error => {
        this.saving.set(false);
        select.value = previous;
        this.error.set(apiErrorMessage(error, 'Não foi possível mudar a presença.'));
      }
    });
  }
}
