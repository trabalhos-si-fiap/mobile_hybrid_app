import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';

import { AuthService } from '../services/auth.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const router = inject(Router);
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
        router.navigate(['/login'], { queryParams: { sessao: 'expirada' } });
      }

      return throwError(() => error);
    })
  );
};
