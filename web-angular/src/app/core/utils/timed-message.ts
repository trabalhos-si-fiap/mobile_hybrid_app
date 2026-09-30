import { signal } from '@angular/core';

/** Texto de um toast que some sozinho; chame clear() quando a tela for destruída. */
export class TimedMessage {
  readonly text = signal('');

  private timer: ReturnType<typeof setTimeout> | null = null;

  constructor(private readonly durationMs = 3200) {}

  show(text: string): void {
    this.clear();
    this.text.set(text);
    this.timer = setTimeout(() => {
      this.text.set('');
      this.timer = null;
    }, this.durationMs);
  }

  clear(): void {
    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    this.text.set('');
  }
}
