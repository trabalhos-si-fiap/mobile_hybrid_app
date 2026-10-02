import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { OmnichannelDashboard } from '../models/omnichannel-dashboard.model';
import { anOverview } from '../../testing/dashboard-data';
import { OmnichannelDashboardService } from './omnichannel-dashboard.service';

describe('OmnichannelDashboardService', () => {
  let service: OmnichannelDashboardService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(OmnichannelDashboardService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('asks for the attendance summary of the chosen period', () => {
    let body: OmnichannelDashboard | undefined;
    service.get(30).subscribe((data) => (body = data));

    const request = http.expectOne((req) => req.url === '/api/v1/dashboard/omnichannel');
    expect(request.request.method).toBe('GET');
    expect(request.request.params.get('days')).toBe('30');
    request.flush(anOverview({ days: 30 }));

    expect(body?.days).toBe(30);
  });
});
