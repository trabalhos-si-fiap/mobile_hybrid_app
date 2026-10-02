import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';

import { DashboardService } from '../../core/services/dashboard.service';
import { OmnichannelDashboardService } from '../../core/services/omnichannel-dashboard.service';
import { aDashboard, anOverview } from '../../testing/dashboard-data';
import { httpError } from '../../testing/test-data';
import { DashboardComponent } from './dashboard.component';

describe('DashboardComponent', () => {
  let getDashboard: Mock;

  beforeEach(() => {
    getDashboard = vi.fn(() => of(aDashboard()));
  });

  async function render(): Promise<ComponentFixture<DashboardComponent>> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: DashboardService, useValue: { getDashboard } },
        { provide: OmnichannelDashboardService, useValue: { get: vi.fn(() => of(anOverview())) } },
      ],
    });
    const fixture = TestBed.createComponent(DashboardComponent);
    await fixture.whenStable();
    return fixture;
  }

  it('puts the attendance overview on top of the operational control', async () => {
    const fixture = await render();

    const overview: HTMLElement = fixture.nativeElement.querySelector('app-omnichannel-overview');
    const operational: HTMLElement = fixture.nativeElement.querySelector('.operational-section');
    expect(overview.textContent).toContain('Visão do atendimento');
    expect(operational.textContent).toContain('Controle Operacional');
    expect(operational.textContent).toContain('PRODUTOS CADASTRADOS');
    expect(
      overview.compareDocumentPosition(operational) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
  });

  it('no longer shows the educational block nor the old executive summary', async () => {
    const fixture = await render();

    const text: string = fixture.nativeElement.textContent;
    expect(text).not.toContain('Visão Educacional');
    expect(text).not.toContain('ATIVIDADE E CADASTROS');
    expect(text).not.toContain('Resumo Executivo');
    expect(text).not.toContain(aDashboard().executiveSummary);
  });

  it('keeps the overview when the operational data fails', async () => {
    getDashboard.mockReturnValue(throwError(() => httpError(500)));
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Não foi possível carregar o dashboard.');
    expect(fixture.nativeElement.querySelector('app-omnichannel-overview').textContent).toContain(
      'Visão do atendimento',
    );
  });
});
