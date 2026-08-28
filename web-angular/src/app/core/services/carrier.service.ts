import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { forkJoin, map, Observable, tap } from 'rxjs';

import {
  Carrier,
  CarrierPage,
  CarrierRequest,
  CarrierStatus,
  CarrierSummary
} from '../models/carrier.model';
import { DashboardService } from './dashboard.service';

@Injectable({ providedIn: 'root' })
export class CarrierService {
  private readonly http = inject(HttpClient);
  private readonly dashboardService = inject(DashboardService);
  private readonly apiUrl = '/api/v1';

  listCarriers(
    page = 0,
    size = 3,
    search = '',
    status: CarrierStatus | '' = ''
  ): Observable<CarrierPage> {
    let params = new HttpParams()
      .set('page', String(page))
      .set('size', String(size));

    if (search.trim()) {
      params = params.set('search', search.trim());
    }

    if (status) {
      params = params.set('status', status);
    }

    return this.http.get<CarrierPage>(
      `${this.apiUrl}/carriers`,
      { params }
    );
  }

  createCarrier(request: CarrierRequest): Observable<Carrier> {
    return this.http
      .post<Carrier>(`${this.apiUrl}/carriers`, request)
      .pipe(
        tap(() => this.dashboardService.invalidateCache())
      );
  }

  updateCarrier(
    id: number,
    request: CarrierRequest
  ): Observable<Carrier> {
    return this.http
      .put<Carrier>(
        `${this.apiUrl}/carriers/${id}`,
        request
      )
      .pipe(
        tap(() => this.dashboardService.invalidateCache())
      );
  }

  updateStatus(
    id: number,
    status: CarrierStatus
  ): Observable<Carrier> {
    return this.http
      .patch<Carrier>(
        `${this.apiUrl}/carriers/${id}/status`,
        { status }
      )
      .pipe(
        tap(() => this.dashboardService.invalidateCache())
      );
  }

  getAllCarriers(): Observable<Carrier[]> {
    return this.listCarriers(0, 100).pipe(
      map(page => page.content)
    );
  }

  getSummary(): Observable<CarrierSummary> {
    return forkJoin({
      firstPage: this.listCarriers(0, 1),
      dashboard: this.dashboardService.getDashboard(30)
    }).pipe(
      map(({ firstPage, dashboard }) => {
        const total = firstPage.totalElements;
        const active = dashboard.operational.activeCarriers;

        return {
          total,
          active,
          inactive: Math.max(0, total - active)
        };
      })
    );
  }
}
