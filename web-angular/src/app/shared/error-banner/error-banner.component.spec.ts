import { describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';

import { ErrorBannerComponent } from './error-banner.component';

describe('ErrorBannerComponent', () => {
  it('shows the message and emits dismissed on the ×', async () => {
    const fixture = TestBed.createComponent(ErrorBannerComponent);
    fixture.componentRef.setInput('message', 'Ticket 12 está fechado');
    let dismissed = false;
    fixture.componentInstance.dismissed.subscribe(() => (dismissed = true));
    await fixture.whenStable();

    const element: HTMLElement = fixture.nativeElement;
    expect(element.querySelector('[role="alert"]')?.textContent).toContain(
      'Ticket 12 está fechado',
    );

    element.querySelector<HTMLButtonElement>('button')!.click();
    expect(dismissed).toBe(true);
  });
});
