import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

import { DashboardPeriod, OmnichannelDashboard } from '../models/omnichannel-dashboard.model';

/** Resumo do atendimento (PR_RESUMO_DASHBOARD). Sem cache: cada período é buscado de novo. */
@Injectable({ providedIn: 'root' })
export class OmnichannelDashboardService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  get(days: DashboardPeriod): Observable<OmnichannelDashboard> {
    const params = new HttpParams().set('days', String(days));
    return this.http.get<OmnichannelDashboard>(`${this.apiUrl}/dashboard/omnichannel`, { params });
  }
}
