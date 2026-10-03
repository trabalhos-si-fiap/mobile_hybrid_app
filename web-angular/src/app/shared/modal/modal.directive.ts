import { DOCUMENT } from '@angular/common';
import { afterNextRender, Directive, ElementRef, inject, OnDestroy, output } from '@angular/core';

const CONTROLS = 'a[href], button, input, select, textarea, [tabindex]';
const FIELDS = 'input, select, textarea';

/**
 * Comportamento de teclado do cartão de um diálogo modal: Escape pede para fechar, o foco
 * entra no primeiro campo, o Tab não sai do cartão e o foco volta a quem abriu ao destruir.
 */
@Directive({
  selector: '[appModal]',
  standalone: true,
  host: {
    tabindex: '-1',
    '(keydown)': 'onKeydown($event)',
    '(document:keydown.escape)': 'dismissed.emit()',
  },
})
export class ModalDirective implements OnDestroy {
  private readonly card = inject<ElementRef<HTMLElement>>(ElementRef).nativeElement;
  private readonly document = inject(DOCUMENT);
  private readonly opener = this.document.activeElement as HTMLElement | null;

  readonly dismissed = output<void>({ alias: 'appModalDismiss' });

  constructor() {
    afterNextRender(() => this.focusFirstField());
  }

  ngOnDestroy(): void {
    if (this.opener?.isConnected) {
      this.opener.focus();
    }
  }

  /** Foca o primeiro campo habilitado, ou o cartão; não mexe se o foco já está dentro. */
  focusFirstField(): void {
    const active = this.document.activeElement;
    if (active && active !== this.card && this.card.contains(active)) {
      return;
    }
    const field = this.controls().find((control) => control.matches(FIELDS));
    (field ?? this.card).focus();
  }

  onKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Tab') {
      return;
    }

    const controls = this.controls();
    if (controls.length === 0) {
      event.preventDefault();
      this.card.focus();
      return;
    }

    const first = controls[0];
    const last = controls[controls.length - 1];
    const active = this.document.activeElement;
    const outside = !active || !this.card.contains(active) || active === this.card;

    if (event.shiftKey && (active === first || outside)) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && (active === last || outside)) {
      event.preventDefault();
      first.focus();
    }
  }

  private controls(): HTMLElement[] {
    return Array.from(this.card.querySelectorAll<HTMLElement>(CONTROLS)).filter(
      (control) => control.tabIndex >= 0 && !control.matches(':disabled'),
    );
  }
}
