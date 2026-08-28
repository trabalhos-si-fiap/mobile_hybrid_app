import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { tap } from 'rxjs';

import { LoginResponse } from '../models/auth.model';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);

  private readonly apiUrl = '/api/v1';
  private readonly tokenKey = 'edu_admin_token';
  private readonly userKey = 'edu_admin_user';

  login(email: string, password: string, remember: boolean) {
    return this.http
      .post<LoginResponse>(`${this.apiUrl}/auth/login`, { email, password })
      .pipe(
        tap(response => {
          this.clearStorages();

          const storage = remember ? localStorage : sessionStorage;
          storage.setItem(this.tokenKey, response.accessToken);
          storage.setItem(this.userKey, JSON.stringify(response.user));
        })
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
