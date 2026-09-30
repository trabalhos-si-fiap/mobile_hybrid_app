import { beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import {
  ActivatedRouteSnapshot,
  provideRouter,
  Router,
  RouterStateSnapshot,
  UrlTree,
} from '@angular/router';

import { authGuard } from './auth.guard';

describe('authGuard', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    TestBed.configureTestingModule({ providers: [provideRouter([])] });
  });

  function runGuard(): boolean | UrlTree {
    return TestBed.runInInjectionContext(() =>
      authGuard({} as ActivatedRouteSnapshot, {} as RouterStateSnapshot),
    ) as boolean | UrlTree;
  }

  function redirect(result: boolean | UrlTree): string {
    return TestBed.inject(Router).serializeUrl(result as UrlTree);
  }

  function store(user: object | null): void {
    localStorage.setItem('edu_admin_token', 'jwt');
    if (user) {
      localStorage.setItem('edu_admin_user', JSON.stringify(user));
    }
  }

  it('lets staff in', () => {
    store({ id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' });

    expect(runGuard()).toBe(true);
  });

  it('sends visitors without a token to the login', () => {
    expect(redirect(runGuard())).toBe('/login');
  });

  it('drops a leftover USER token and sends to the login', () => {
    store({ id: 50, name: 'Ana Usuária', email: 'ana@edu.com', role: 'USER' });

    expect(redirect(runGuard())).toBe('/login');
    expect(localStorage.getItem('edu_admin_token')).toBeNull();
  });

  it('drops a token stored without its user', () => {
    store(null);

    expect(redirect(runGuard())).toBe('/login');
    expect(localStorage.getItem('edu_admin_token')).toBeNull();
  });
});
