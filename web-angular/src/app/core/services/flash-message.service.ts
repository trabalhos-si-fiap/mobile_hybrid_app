import { Injectable } from '@angular/core';

/** Aviso de sucesso que sobrevive a uma navegação (ex.: console → fila depois de transferir). */
@Injectable({ providedIn: 'root' })
export class FlashMessageService {
  private message: string | null = null;

  set(message: string): void {
    this.message = message;
  }

  take(): string | null {
    const message = this.message;
    this.message = null;
    return message;
  }
}
