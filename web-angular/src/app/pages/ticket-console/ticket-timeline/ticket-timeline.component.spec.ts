import { describe, expect, it } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TicketEvent } from '../../../core/models/ticket.model';
import { TicketTimelineComponent } from './ticket-timeline.component';

const EVENTS: TicketEvent[] = [
  {
    id: 1,
    type: 'ABERTO',
    fromStatus: null,
    toStatus: 'ABERTO',
    employeeName: null,
    detail: null,
    createdAt: '2026-09-29T10:00:00Z',
  },
  {
    id: 2,
    type: 'ALERTA_ENGENHARIA',
    fromStatus: 'EM_ATENDIMENTO',
    toStatus: 'EM_ATENDIMENTO',
    employeeName: 'Diego Dev',
    detail: 'Crash no checkout',
    createdAt: '2026-09-29T11:00:00Z',
  },
];

describe('TicketTimelineComponent', () => {
  async function render(): Promise<ComponentFixture<TicketTimelineComponent>> {
    const fixture = TestBed.createComponent(TicketTimelineComponent);
    fixture.componentRef.setInput('events', EVENTS);
    await fixture.whenStable();
    return fixture;
  }

  function toggle(fixture: ComponentFixture<TicketTimelineComponent>): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button');
  }

  it('starts collapsed, with the count on the button', async () => {
    const fixture = await render();

    expect(toggle(fixture).textContent?.trim()).toBe('Linha do tempo (2)');
    expect(toggle(fixture).getAttribute('aria-expanded')).toBe('false');
    expect(fixture.nativeElement.querySelector('ol')).toBeNull();
  });

  it('shows type, statuses, agent, detail and date when expanded', async () => {
    const fixture = await render();

    toggle(fixture).click();
    await fixture.whenStable();

    const list: HTMLElement = fixture.nativeElement.querySelector(
      'ol[aria-label="Linha do tempo"]',
    );
    const items = list.querySelectorAll('li');
    expect(items[0].textContent).toContain('Aberto');
    expect(items[0].textContent).not.toContain('→');
    expect(items[1].textContent).toContain('Alerta de engenharia');
    expect(items[1].textContent).toContain('Em atendimento → Em atendimento');
    expect(items[1].textContent).toContain('por Diego Dev');
    expect(items[1].textContent).toContain('Crash no checkout');
  });
});
