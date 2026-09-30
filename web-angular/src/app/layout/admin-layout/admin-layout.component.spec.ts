import { describe, expect, it, vi } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideRouter, RouterOutlet } from '@angular/router';
import { of } from 'rxjs';

import { EmployeeService } from '../../core/services/employee.service';
import { AdminLayoutComponent } from './admin-layout.component';

describe('AdminLayoutComponent', () => {
  it('loads the agent when the layout opens', async () => {
    const load = vi.fn(() => of(null));
    TestBed.configureTestingModule({
      providers: [provideRouter([]), { provide: EmployeeService, useValue: { load } }],
    });
    TestBed.overrideComponent(AdminLayoutComponent, {
      set: { imports: [RouterOutlet], template: '<router-outlet />' },
    });

    const fixture = TestBed.createComponent(AdminLayoutComponent);
    await fixture.whenStable();

    expect(load).toHaveBeenCalledTimes(1);
  });
});
