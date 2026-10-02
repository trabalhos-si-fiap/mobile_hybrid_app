import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';

import {
  DashboardPeriod,
  OmnichannelDashboard,
} from '../../../core/models/omnichannel-dashboard.model';
import { OmnichannelDashboardService } from '../../../core/services/omnichannel-dashboard.service';
import { anEmptyOverview, anOverview } from '../../../testing/dashboard-data';
import { httpError } from '../../../testing/test-data';
import { OmnichannelOverviewComponent } from './omnichannel-overview.component';

describe('OmnichannelOverviewComponent', () => {
  let get: Mock;

  beforeEach(() => {
    get = vi.fn(() => of(anOverview()));
  });

  async function render(): Promise<ComponentFixture<OmnichannelOverviewComponent>> {
    TestBed.configureTestingModule({
      providers: [{ provide: OmnichannelDashboardService, useValue: { get } }],
    });
    const fixture = TestBed.createComponent(OmnichannelOverviewComponent);
    await fixture.whenStable();
    return fixture;
  }

  function el(fixture: ComponentFixture<unknown>, selector: string): HTMLElement {
    return fixture.nativeElement.querySelector(selector);
  }

  function kpiValue(fixture: ComponentFixture<unknown>, key: string): string {
    return el(fixture, `[data-kpi="${key}"] strong`).textContent!.trim();
  }

  function badge(fixture: ComponentFixture<unknown>, key: string): [string, string | null] {
    const node = el(fixture, `[data-kpi="${key}"] .badge`);
    return [node.textContent!.trim(), node.getAttribute('data-tone')];
  }

  function button(fixture: ComponentFixture<unknown>, label: string): HTMLButtonElement {
    return Array.from<HTMLButtonElement>(fixture.nativeElement.querySelectorAll('button')).find(
      (candidate) => candidate.textContent!.trim() === label,
    )!;
  }

  it('loads the last 7 days and shows the KPI cards', async () => {
    const fixture = await render();

    expect(get).toHaveBeenCalledWith(7);
    expect(button(fixture, '7 dias').getAttribute('aria-pressed')).toBe('true');
    expect(el(fixture, '.legend').textContent).toContain('vs. 7 dias anteriores');
    expect(kpiValue(fixture, 'opened')).toBe('31');
    expect(kpiValue(fixture, 'sla')).toBe('88,9%');
    expect(kpiValue(fixture, 'assume')).toBe('14,5 min');
    expect(kpiValue(fixture, 'resolve')).toBe('6,2 h');
    expect(kpiValue(fixture, 'backlog')).toBe('6');
    expect(el(fixture, '[data-kpi="backlog"] .badge')).toBeNull();
  });

  it('colours each variation by the direction that is good for the metric', async () => {
    const fixture = await render();

    expect(badge(fixture, 'opened')).toEqual(['▲ 29,2%', 'bad']);
    expect(badge(fixture, 'resolved')).toEqual(['▲ 8%', 'good']);
    expect(badge(fixture, 'sla')).toEqual(['▼ 3,4%', 'bad']);
    expect(badge(fixture, 'assume')).toEqual(['▼ 19,4%', 'good']);
    expect(badge(fixture, 'escalated')).toEqual(['0%', 'neutral']);
    expect(badge(fixture, 'resolve')).toEqual(['— sem base', 'none']);
  });

  it('splits the opened tickets by channel', async () => {
    const fixture = await render();

    const app = el(fixture, '[data-channel="app"]');
    const chatbot = el(fixture, '[data-channel="chatbot"]');
    expect(app.textContent).toContain('App');
    expect(app.querySelector('b')!.textContent).toBe('26');
    expect(app.querySelector('.badge')!.textContent!.trim()).toBe('▲ 23,8%');
    expect(chatbot.textContent).toContain('Chatbot');
    expect(chatbot.querySelector('b')!.textContent).toBe('5');
    expect(chatbot.querySelector('.badge')!.textContent!.trim()).toBe('▲ 66,7%');
  });

  it('marks the anomalies of the last 24 hours', async () => {
    const fixture = await render();

    const items = Array.from<HTMLElement>(
      fixture.nativeElement.querySelectorAll('[aria-label="Anomalias das últimas 24 horas"] li'),
    );
    expect(items.map((item) => item.getAttribute('data-status'))).toEqual([
      'NORMAL',
      'PICO',
      'SEM_HISTORICO',
    ]);
    expect(items.map((item) => item.querySelector('em')!.textContent!.trim())).toEqual([
      'Normal',
      'Pico',
      'Sem histórico',
    ]);
    expect(items[1].textContent).toContain('Problemas com pedido');
    expect(items[1].textContent).toContain('12 tickets · média 3,5');
    expect(items[2].textContent).toContain('0 tickets · média —');
  });

  it('lists every segment with its variations', async () => {
    const fixture = await render();

    const rows = Array.from<HTMLTableRowElement>(
      fixture.nativeElement.querySelectorAll('tbody tr'),
    );
    expect(rows.map((row) => row.getAttribute('data-segment'))).toEqual([
      'DEFEITO_APP',
      'PROBLEMA_PEDIDO',
      'FEEDBACK_SUGESTAO',
    ]);
    expect(rows[1].querySelector('th')!.textContent).toContain('Problemas com pedido');
    const cells = Array.from(rows[1].querySelectorAll('td')).map((cell) =>
      cell.textContent!.replace(/\s+/g, ' ').trim(),
    );
    expect(cells).toEqual(['15 ▲ 50%', '12 ▲ 20%', '91,7% ▲ 1,9%', '3']);
  });

  it('shows the highlights', async () => {
    const fixture = await render();

    const lines = Array.from<HTMLElement>(
      fixture.nativeElement.querySelectorAll('.highlights li'),
    ).map((line) => line.textContent!.trim());
    expect(lines).toEqual([
      'Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,5.',
    ]);
  });

  it('switches the period and drops a late answer from the previous one', async () => {
    const answers: Record<DashboardPeriod, Subject<OmnichannelDashboard>> = {
      7: new Subject(),
      30: new Subject(),
      90: new Subject(),
    };
    get.mockImplementation((days: DashboardPeriod) => answers[days]);
    const fixture = await render();
    expect(fixture.nativeElement.textContent).toContain('Carregando atendimento...');

    button(fixture, '30 dias').click();
    await fixture.whenStable();
    answers[7].next(anOverview({ days: 7 }));
    await fixture.whenStable();
    expect(fixture.nativeElement.textContent).toContain('Carregando atendimento...');

    answers[30].next(anOverview({ days: 30 }));
    await fixture.whenStable();
    expect(get).toHaveBeenLastCalledWith(30);
    expect(button(fixture, '30 dias').getAttribute('aria-pressed')).toBe('true');
    expect(button(fixture, '7 dias').getAttribute('aria-pressed')).toBe('false');
    expect(el(fixture, '.legend').textContent).toContain('vs. 30 dias anteriores');
  });

  it('shows an error with a retry that asks again', async () => {
    get.mockReturnValueOnce(throwError(() => httpError(500)));
    const fixture = await render();

    expect(el(fixture, '[role="alert"]').textContent).toContain(
      'Não foi possível carregar o atendimento.',
    );

    button(fixture, 'Tentar de novo').click();
    await fixture.whenStable();

    expect(get).toHaveBeenCalledTimes(2);
    expect(get).toHaveBeenLastCalledWith(7);
    expect(el(fixture, '[role="alert"]')).toBeNull();
    expect(kpiValue(fixture, 'opened')).toBe('31');
  });

  it('shows dashes when there is no data yet', async () => {
    get.mockReturnValue(of(anEmptyOverview()));
    const fixture = await render();

    expect(kpiValue(fixture, 'opened')).toBe('0');
    expect(badge(fixture, 'opened')).toEqual(['— sem base', 'none']);
    expect(kpiValue(fixture, 'sla')).toBe('—');
    expect(kpiValue(fixture, 'assume')).toBe('—');
    expect(fixture.nativeElement.textContent).toContain('0 tickets · média —');
    expect(fixture.nativeElement.textContent).not.toMatch(/NaN|null|undefined/);
  });
});
