import { describe, expect, it } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ConfirmDialogComponent } from './confirm-dialog.component';

describe('ConfirmDialogComponent', () => {
  async function render(): Promise<{
    fixture: ComponentFixture<ConfirmDialogComponent>;
    events: string[];
  }> {
    const fixture = TestBed.createComponent(ConfirmDialogComponent);
    fixture.componentRef.setInput('heading', 'Encerrar ticket');
    fixture.componentRef.setInput('message', 'O ticket #12 será marcado como resolvido.');
    fixture.componentRef.setInput('confirmLabel', 'Encerrar');
    const events: string[] = [];
    fixture.componentInstance.confirmed.subscribe(() => events.push('confirmed'));
    fixture.componentInstance.cancelled.subscribe(() => events.push('cancelled'));
    await fixture.whenStable();
    return { fixture, events };
  }

  function button(
    fixture: ComponentFixture<ConfirmDialogComponent>,
    label: string,
  ): HTMLButtonElement {
    const buttons = Array.from<HTMLButtonElement>(fixture.nativeElement.querySelectorAll('button'));
    return buttons.find((item) => item.textContent?.trim() === label)!;
  }

  it('is a dialog with the heading and the message', async () => {
    const { fixture } = await render();

    const dialog = fixture.nativeElement.querySelector('[role="dialog"]');
    expect(dialog.getAttribute('aria-label')).toBe('Encerrar ticket');
    expect(dialog.textContent).toContain('O ticket #12 será marcado como resolvido.');
  });

  it('emits confirmed on the confirm button', async () => {
    const { fixture, events } = await render();

    button(fixture, 'Encerrar').click();

    expect(events).toEqual(['confirmed']);
  });

  it('emits cancelled on Cancelar', async () => {
    const { fixture, events } = await render();

    button(fixture, 'Cancelar').click();

    expect(events).toEqual(['cancelled']);
  });
});
