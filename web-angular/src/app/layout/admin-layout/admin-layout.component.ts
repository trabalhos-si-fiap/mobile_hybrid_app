import { Component, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { RouterOutlet } from '@angular/router';

import { EmployeeService } from '../../core/services/employee.service';
import { SidebarComponent } from '../sidebar/sidebar.component';

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [RouterOutlet, SidebarComponent],
  templateUrl: './admin-layout.component.html',
  styleUrl: './admin-layout.component.scss'
})
export class AdminLayoutComponent {
  constructor() {
    // O atendente (presença e skills) é lido pela fila, pelo console e pelo cartão.
    inject(EmployeeService)
      .load()
      .pipe(takeUntilDestroyed())
      .subscribe({ error: () => undefined });
  }
}
