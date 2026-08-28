import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import {
  CarrierOccurrence,
  OccurrencePage,
  OccurrenceStatus,
  OccurrenceType
} from '../models/occurrence.model';
import { DashboardService } from './dashboard.service';

@Injectable({ providedIn: 'root' })
export class OccurrenceService {
  private readonly http = inject(HttpClient);
  private readonly dashboardService = inject(DashboardService);
  private readonly apiUrl = '/api/v1';

  listOccurrences(
    page = 0,
    size = 3,
    carrierId: number | null = null,
    type: OccurrenceType | '' = '',
    status: OccurrenceStatus | '' = ''
  ): Observable<OccurrencePage> {
    let params = new HttpParams()
      .set('page', String(page))
      .set('size', String(size));

    if (carrierId !== null) {
      params = params.set('carrierId', String(carrierId));
    }

    if (type) {
      params = params.set('type', type);
    }

    if (status) {
      params = params.set('status', status);
    }

    return this.http.get<OccurrencePage>(
      `${this.apiUrl}/carrier-occurrences`,
      { params }
    );
  }

  getOccurrence(id: number): Observable<CarrierOccurrence> {
    return this.http.get<CarrierOccurrence>(
      `${this.apiUrl}/carrier-occurrences/${id}`
    );
  }

  updateStatus(
    id: number,
    status: OccurrenceStatus
  ): Observable<CarrierOccurrence> {
    return this.http
      .patch<CarrierOccurrence>(
        `${this.apiUrl}/carrier-occurrences/${id}/status`,
        { status }
      )
      .pipe(
        tap(() => this.dashboardService.invalidateCache())
      );
  }
}
