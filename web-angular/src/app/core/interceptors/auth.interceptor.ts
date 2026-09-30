import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';

import { AuthService } from '../services/auth.service';
import { EmployeeService } from '../services/employee.service';
import { NotificationService } from '../services/notification.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const employees = inject(EmployeeService);
  const notifications = inject(NotificationService);
  const isLogin = req.url.includes('/auth/login');
  const token = auth.getToken();

  const request =
    token && !isLogin
      ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
      : req;

  return next(request).pipe(
    catchError((error: unknown) => {
      if (!isLogin && error instanceof HttpErrorResponse && error.status === 401) {
        auth.logout();
        employees.clear();
        notifications.clear();
        router.navigate(['/login'], { queryParams: { sessao: 'expirada' } });
      }

      return throwError(() => error);
    })
  );
};
