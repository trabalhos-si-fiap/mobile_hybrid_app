import { beforeEach, describe, expect, it } from 'vitest';
import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ModalDirective } from './modal.directive';

@Component({
  standalone: true,
  imports: [ModalDirective],
  template: `
    <button id="opener" type="button">Abrir</button>
    @if (open()) {
      <section appModal role="dialog" (appModalDismiss)="dismissals.set(dismissals() + 1)">
        <button id="close" type="button">Fechar</button>
        @if (withField()) {
          <input id="field" />
        }
        <button id="last" type="button">Último</button>
      </section>
    }
  `,
})
class HostComponent {
  readonly open = signal(false);
  readonly withField = signal(true);
  readonly dismissals = signal(0);
}

describe('ModalDirective', () => {
  let fixture: ComponentFixture<HostComponent>;

  beforeEach(async () => {
    fixture = TestBed.createComponent(HostComponent);
    await fixture.whenStable();
  });

  async function open(): Promise<void> {
    fixture.componentInstance.open.set(true);
    await fixture.whenStable();
  }

  function el<T extends HTMLElement>(id: string): T {
    return fixture.nativeElement.querySelector(`#${id}`);
  }

  function press(target: HTMLElement, init: KeyboardEventInit): KeyboardEvent {
    const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, ...init });
    target.dispatchEvent(event);
    return event;
  }

  it('focuses the first field when it opens', async () => {
    await open();

    expect(document.activeElement).toBe(el('field'));
  });

  it('focuses the dialog itself when there is no field', async () => {
    fixture.componentInstance.withField.set(false);
    await open();

    expect(document.activeElement).toBe(fixture.nativeElement.querySelector('[role="dialog"]'));
  });

  it('emits appModalDismiss on Escape', async () => {
    await open();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(fixture.componentInstance.dismissals()).toBe(1);
  });

  it('wraps Tab from the last control to the first', async () => {
    await open();
    el('last').focus();

    const event = press(el('last'), { key: 'Tab' });

    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(el('close'));
  });

  it('wraps Shift+Tab from the first control to the last', async () => {
    await open();
    el('close').focus();

    const event = press(el('close'), { key: 'Tab', shiftKey: true });

    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(el('last'));
  });

  it('leaves Tab alone in the middle of the dialog', async () => {
    await open();
    el('field').focus();

    const event = press(el('field'), { key: 'Tab' });

    expect(event.defaultPrevented).toBe(false);
  });

  it('gives the focus back to what had it before opening', async () => {
    el('opener').focus();
    await open();
    expect(document.activeElement).toBe(el('field'));

    fixture.componentInstance.open.set(false);
    await fixture.whenStable();

    expect(document.activeElement).toBe(el('opener'));
  });
});
