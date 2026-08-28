import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, shareReplay } from 'rxjs';

import { DashboardResponse } from '../models/dashboard.model';

@Injectable({ providedIn: 'root' })
export class DashboardService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  private dashboard30Days$?: Observable<DashboardResponse>;

  getDashboard(days = 30): Observable<DashboardResponse> {
    if (days === 30) {
      if (!this.dashboard30Days$) {
        this.dashboard30Days$ = this.requestDashboard(days).pipe(
          shareReplay({ bufferSize: 1, refCount: false })
        );
      }

      return this.dashboard30Days$;
    }

    return this.requestDashboard(days);
  }

  invalidateCache(): void {
    this.dashboard30Days$ = undefined;
  }

  private requestDashboard(days: number): Observable<DashboardResponse> {
    const params = new HttpParams().set('days', String(days));

    return this.http.get<DashboardResponse>(
      `${this.apiUrl}/dashboard`,
      { params }
    );
  }
}
