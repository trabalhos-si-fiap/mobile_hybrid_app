import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

import { AuthService } from '../services/auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.isAuthenticated()) {
    return router.createUrlTree(['/login']);
  }

  if (!auth.isStaff()) {
    // Token guardado de antes desta regra (conta USER ou sem usuário): descarta.
    auth.logout();
    return router.createUrlTree(['/login']);
  }

  return true;
};
