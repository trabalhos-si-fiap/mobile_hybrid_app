import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of } from 'rxjs';

import { TicketService } from '../../../core/services/ticket.service';
import { TicketAction } from '../../../core/utils/ticket-permissions';
import { aTicket, SEGMENTS } from '../../../testing/test-data';
import { TicketActionsBarComponent } from './ticket-actions-bar.component';

describe('TicketActionsBarComponent', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        {
          provide: TicketService,
          useValue: {
            segments: () => of(SEGMENTS),
            transfer: vi.fn(),
            raiseEngineeringAlert: vi.fn(),
          },
        },
      ],
    });
  });

  async function render(
    actions: TicketAction[],
    busy = false,
  ): Promise<{
    fixture: ComponentFixture<TicketActionsBarComponent>;
    assume: Mock;
    resolve: Mock;
  }> {
    const fixture = TestBed.createComponent(TicketActionsBarComponent);
    fixture.componentRef.setInput('ticket', aTicket());
    fixture.componentRef.setInput('actions', actions);
    fixture.componentRef.setInput('busy', busy);
    const assume = vi.fn();
    const resolve = vi.fn();
    fixture.componentInstance.assume.subscribe(assume);
    fixture.componentInstance.resolve.subscribe(resolve);
    await fixture.whenStable();
    return { fixture, assume, resolve };
  }

  function labels(fixture: ComponentFixture<TicketActionsBarComponent>): string[] {
    return Array.from<HTMLButtonElement>(
      fixture.nativeElement.querySelectorAll('[role="toolbar"] button'),
    ).map((button) => button.textContent!.trim());
  }

  function button(root: HTMLElement, label: string): HTMLButtonElement {
    return Array.from(root.querySelectorAll('button')).find(
      (item) => item.textContent?.trim() === label,
    )!;
  }

  it('shows only the allowed actions', async () => {
    const { fixture } = await render(['resolve', 'transfer', 'engineeringAlert']);

    expect(labels(fixture)).toEqual(['Encerrar', 'Transferir', 'Alertar engenharia']);
  });

  it('emits assume', async () => {
    const { fixture, assume } = await render(['assume']);

    button(fixture.nativeElement, 'Assumir').click();

    expect(assume).toHaveBeenCalled();
  });

  it('asks before resolving', async () => {
    const { fixture, resolve } = await render(['resolve']);

    button(fixture.nativeElement, 'Encerrar').click();
    await fixture.whenStable();
    expect(resolve).not.toHaveBeenCalled();

    const dialog: HTMLElement = fixture.nativeElement.querySelector('[role="dialog"]');
    button(dialog, 'Encerrar').click();
    await fixture.whenStable();

    expect(resolve).toHaveBeenCalledTimes(1);
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
  });

  it('does not resolve when the confirmation is cancelled', async () => {
    const { fixture, resolve } = await render(['resolve']);

    button(fixture.nativeElement, 'Encerrar').click();
    await fixture.whenStable();
    button(fixture.nativeElement.querySelector('[role="dialog"]'), 'Cancelar').click();
    await fixture.whenStable();

    expect(resolve).not.toHaveBeenCalled();
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
  });

  it('opens the transfer and the alert modals', async () => {
    const { fixture } = await render(['transfer', 'engineeringAlert']);

    button(fixture.nativeElement, 'Transferir').click();
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-transfer-modal')).not.toBeNull();

    button(fixture.nativeElement.querySelector('[role="dialog"]'), 'Cancelar').click();
    await fixture.whenStable();
    button(fixture.nativeElement, 'Alertar engenharia').click();
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-engineering-alert-modal')).not.toBeNull();
  });

  it('disables the buttons while an action runs', async () => {
    const { fixture } = await render(['resolve', 'transfer'], true);

    expect(button(fixture.nativeElement, 'Encerrar').disabled).toBe(true);
    expect(button(fixture.nativeElement, 'Transferir').disabled).toBe(true);
  });
});
