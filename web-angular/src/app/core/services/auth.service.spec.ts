import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { AuthUser } from '../models/auth.model';
import { AuthService } from './auth.service';

const EMPLOYEE: AuthUser = { id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' };
const CLIENT: AuthUser = { id: 50, name: 'Ana Usuária', email: 'ana@edu.com', role: 'USER' };

describe('AuthService', () => {
  let auth: AuthService;
  let http: HttpTestingController;

  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    auth = TestBed.inject(AuthService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  function login(user: AuthUser, remember: boolean): AuthUser | undefined {
    let result: AuthUser | undefined;
    auth.login(user.email, 'secret', remember).subscribe((value) => (result = value));
    http.expectOne('/api/v1/auth/login').flush({ accessToken: 'jwt', tokenType: 'Bearer', user });
    return result;
  }

  it('keeps a staff session in localStorage when asked to remember', () => {
    expect(login(EMPLOYEE, true)).toEqual(EMPLOYEE);

    expect(localStorage.getItem('edu_admin_token')).toBe('jwt');
    expect(auth.currentUser()).toEqual(EMPLOYEE);
    expect(auth.isStaff()).toBe(true);
    expect(auth.isAdmin()).toBe(false);
  });

  it('keeps a staff session in sessionStorage otherwise', () => {
    login({ ...EMPLOYEE, role: 'ADMIN' }, false);

    expect(sessionStorage.getItem('edu_admin_token')).toBe('jwt');
    expect(localStorage.getItem('edu_admin_token')).toBeNull();
    expect(auth.isAdmin()).toBe(true);
  });

  it('never stores the session of a USER account', () => {
    expect(login(CLIENT, true)).toEqual(CLIENT);

    expect(auth.getToken()).toBeNull();
    expect(auth.currentUser()).toBeNull();
    expect(auth.isStaff()).toBe(false);
  });

  it('treats an unreadable stored user as no user', () => {
    localStorage.setItem('edu_admin_token', 'jwt');
    localStorage.setItem('edu_admin_user', '{broken');

    expect(auth.currentUser()).toBeNull();
    expect(auth.isStaff()).toBe(false);
  });

  it('logout clears the session', () => {
    login(EMPLOYEE, true);

    auth.logout();

    expect(auth.getToken()).toBeNull();
    expect(auth.currentUser()).toBeNull();
  });
});
