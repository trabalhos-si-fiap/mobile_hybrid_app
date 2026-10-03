import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { TicketService } from '../../core/services/ticket.service';
import { aTicket, httpError } from '../../testing/test-data';
import { EngineeringAlertModalComponent } from './engineering-alert-modal.component';

describe('EngineeringAlertModalComponent', () => {
  let raiseEngineeringAlert: Mock;

  beforeEach(() => {
    raiseEngineeringAlert = vi.fn(() =>
      of(aTicket({ engineeringAlert: true, engineeringAlertReason: 'Crash no checkout' })),
    );
    TestBed.configureTestingModule({
      providers: [{ provide: TicketService, useValue: { raiseEngineeringAlert } }],
    });
  });

  async function render(): Promise<{
    fixture: ComponentFixture<EngineeringAlertModalComponent>;
    raised: Mock;
    failed: Mock;
  }> {
    const fixture = TestBed.createComponent(EngineeringAlertModalComponent);
    fixture.componentRef.setInput('ticket', aTicket());
    const raised = vi.fn();
    const failed = vi.fn();
    fixture.componentInstance.raised.subscribe(raised);
    fixture.componentInstance.failed.subscribe(failed);
    await fixture.whenStable();
    return { fixture, raised, failed };
  }

  async function fillAndSubmit(
    fixture: ComponentFixture<EngineeringAlertModalComponent>,
    reason: string,
  ): Promise<void> {
    const textarea: HTMLTextAreaElement = fixture.nativeElement.querySelector('textarea');
    textarea.value = reason;
    textarea.dispatchEvent(new Event('input'));
    fixture.nativeElement.querySelector('button[type="submit"]').click();
    await fixture.whenStable();
  }

  it('requires a reason', async () => {
    const { fixture } = await render();

    await fillAndSubmit(fixture, '   ');

    expect(raiseEngineeringAlert).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Descreva o motivo do alerta.');
  });

  it('refuses more than 500 characters', async () => {
    const { fixture } = await render();

    await fillAndSubmit(fixture, 'a'.repeat(501));

    expect(raiseEngineeringAlert).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('O motivo passa de 500 caracteres.');
  });

  it('sends the trimmed reason and hands back the ticket', async () => {
    const { fixture, raised } = await render();

    await fillAndSubmit(fixture, '  Crash no checkout  ');

    expect(raiseEngineeringAlert).toHaveBeenCalledWith(12, 'Crash no checkout');
    expect(raised).toHaveBeenCalledWith(expect.objectContaining({ engineeringAlert: true }));
  });

  it('stays open with a generic message on a network failure', async () => {
    raiseEngineeringAlert.mockReturnValue(throwError(() => httpError(0)));
    const { fixture, failed } = await render();

    await fillAndSubmit(fixture, 'Crash');

    expect(fixture.nativeElement.textContent).toContain(
      'Não foi possível concluir. Tente de novo.',
    );
    expect(failed).not.toHaveBeenCalled();
  });

  it('hands a 409 to the console', async () => {
    const conflict = httpError(409, 'Ticket 12 está fechado');
    raiseEngineeringAlert.mockReturnValue(throwError(() => conflict));
    const { fixture, failed } = await render();

    await fillAndSubmit(fixture, 'Crash');

    expect(failed).toHaveBeenCalledWith(conflict);
  });

  it('focuses the reason field when it opens', async () => {
    const { fixture } = await render();

    expect(document.activeElement).toBe(fixture.nativeElement.querySelector('textarea'));
  });

  it('closes on Escape', async () => {
    const { fixture } = await render();
    const closed = vi.fn();
    fixture.componentInstance.closed.subscribe(closed);

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(closed).toHaveBeenCalledTimes(1);
  });
});
