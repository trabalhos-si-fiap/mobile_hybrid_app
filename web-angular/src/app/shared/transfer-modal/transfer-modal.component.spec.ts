import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';

import { TicketService } from '../../core/services/ticket.service';
import { aTicket, httpError, SEGMENTS } from '../../testing/test-data';
import { TransferModalComponent } from './transfer-modal.component';

describe('TransferModalComponent', () => {
  let transfer: Mock;

  beforeEach(() => {
    transfer = vi.fn(() => of(aTicket({ segment: 'FEEDBACK_SUGESTAO', status: 'EM_FILA', assignee: null })));
    TestBed.configureTestingModule({
      providers: [
        { provide: TicketService, useValue: { segments: () => of(SEGMENTS), transfer } }
      ]
    });
  });

  async function render(): Promise<{
    fixture: ComponentFixture<TransferModalComponent>;
    transferred: Mock;
    failed: Mock;
  }> {
    const fixture = TestBed.createComponent(TransferModalComponent);
    fixture.componentRef.setInput('ticket', aTicket());
    const transferred = vi.fn();
    const failed = vi.fn();
    fixture.componentInstance.transferred.subscribe(transferred);
    fixture.componentInstance.failed.subscribe(failed);
    await fixture.whenStable();
    return { fixture, transferred, failed };
  }

  function select(fixture: ComponentFixture<TransferModalComponent>): HTMLSelectElement {
    return fixture.nativeElement.querySelector('select');
  }

  async function choose(fixture: ComponentFixture<TransferModalComponent>, value: string): Promise<void> {
    select(fixture).value = value;
    select(fixture).dispatchEvent(new Event('change'));
    await fixture.whenStable();
  }

  async function submit(fixture: ComponentFixture<TransferModalComponent>): Promise<void> {
    fixture.nativeElement.querySelector('button[type="submit"]').click();
    await fixture.whenStable();
  }

  it('offers every segment but the current one', async () => {
    const { fixture } = await render();

    const options = Array.from<HTMLOptionElement>(select(fixture).options).map(option => option.value);
    expect(options).toEqual(['', 'PROBLEMA_PEDIDO', 'FEEDBACK_SUGESTAO']);
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).not.toBeNull();
  });

  it('asks for a destination', async () => {
    const { fixture } = await render();

    await submit(fixture);

    expect(transfer).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Escolha o segmento de destino.');
  });

  it('transfers and hands back the ticket with the segment label', async () => {
    const { fixture, transferred } = await render();

    await choose(fixture, 'FEEDBACK_SUGESTAO');
    await submit(fixture);

    expect(transfer).toHaveBeenCalledWith(12, 'FEEDBACK_SUGESTAO');
    expect(transferred).toHaveBeenCalledWith({
      ticket: expect.objectContaining({ segment: 'FEEDBACK_SUGESTAO' }),
      label: 'Feedback / Sugestões'
    });
  });

  it('stays open with the API message on a 422', async () => {
    transfer.mockReturnValue(throwError(() => httpError(422, 'Segmento sem configuração ativa')));
    const { fixture, transferred, failed } = await render();

    await choose(fixture, 'PROBLEMA_PEDIDO');
    await submit(fixture);

    expect(fixture.nativeElement.textContent).toContain('Segmento sem configuração ativa');
    expect(transferred).not.toHaveBeenCalled();
    expect(failed).not.toHaveBeenCalled();
  });

  it('hands a 409 to the console', async () => {
    const conflict = httpError(409, 'Ticket 12 não está atribuído a você');
    transfer.mockReturnValue(throwError(() => conflict));
    const { fixture, failed } = await render();

    await choose(fixture, 'PROBLEMA_PEDIDO');
    await submit(fixture);

    expect(failed).toHaveBeenCalledWith(conflict);
  });

  it('ignores a second submit while transferring', async () => {
    transfer.mockReturnValue(new Subject());
    const { fixture } = await render();
    await choose(fixture, 'PROBLEMA_PEDIDO');

    fixture.nativeElement.querySelector('button[type="submit"]').click();
    fixture.nativeElement.querySelector('button[type="submit"]').click();

    expect(transfer).toHaveBeenCalledTimes(1);
  });
});
