import { Component, input, output } from '@angular/core';

/** Faixa de erro no topo da tela; fecha no × (e a tela a limpa na próxima ação bem-sucedida). */
@Component({
  selector: 'app-error-banner',
  standalone: true,
  template: `
    <div class="error-banner" role="alert">
      <span>{{ message() }}</span>
      <button type="button" aria-label="Fechar aviso" (click)="dismissed.emit()">×</button>
    </div>
  `,
  styleUrl: './error-banner.component.scss',
})
export class ErrorBannerComponent {
  readonly message = input.required<string>();
  readonly dismissed = output<void>();
}
