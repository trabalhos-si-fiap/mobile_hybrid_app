import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { map, Observable, tap } from 'rxjs';

import { AuthUser, LoginResponse, UserRole } from '../models/auth.model';

export function isStaffRole(role: UserRole | null | undefined): boolean {
  return role === 'EMPLOYEE' || role === 'ADMIN';
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);

  private readonly apiUrl = '/api/v1';
  private readonly tokenKey = 'edu_admin_token';
  private readonly userKey = 'edu_admin_user';

  /** O painel é só para staff: a sessão de uma conta USER nem chega a ser guardada. */
  login(email: string, password: string, remember: boolean): Observable<AuthUser> {
    return this.http
      .post<LoginResponse>(`${this.apiUrl}/auth/login`, { email, password })
      .pipe(
        tap(response => {
          this.clearStorages();

          if (!isStaffRole(response.user.role)) {
            return;
          }

          const storage = remember ? localStorage : sessionStorage;
          storage.setItem(this.tokenKey, response.accessToken);
          storage.setItem(this.userKey, JSON.stringify(response.user));
        }),
        map(response => response.user)
      );
  }

  getToken(): string | null {
    return (
      localStorage.getItem(this.tokenKey) ??
      sessionStorage.getItem(this.tokenKey)
    );
  }

  isAuthenticated(): boolean {
    return !!this.getToken();
  }

  currentUser(): AuthUser | null {
    const raw =
      localStorage.getItem(this.userKey) ??
      sessionStorage.getItem(this.userKey);

    if (!raw) {
      return null;
    }

    try {
      return JSON.parse(raw) as AuthUser;
    } catch {
      return null;
    }
  }

  isStaff(): boolean {
    return isStaffRole(this.currentUser()?.role);
  }

  isAdmin(): boolean {
    return this.currentUser()?.role === 'ADMIN';
  }

  logout(): void {
    this.clearStorages();
  }

  private clearStorages(): void {
    localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.userKey);
    sessionStorage.removeItem(this.tokenKey);
    sessionStorage.removeItem(this.userKey);
  }
}
