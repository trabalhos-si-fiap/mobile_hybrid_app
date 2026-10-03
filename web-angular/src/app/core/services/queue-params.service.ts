import { Injectable } from '@angular/core';
import { Params } from '@angular/router';

/** A aba e o filtro que a fila mostrava, para o console devolver o atendente ao mesmo ponto. */
@Injectable({ providedIn: 'root' })
export class QueueParamsService {
  private params: Params = {};

  remember(view: { aba: string | null; status: string | null }): void {
    this.params = {
      ...(view.aba ? { aba: view.aba } : {}),
      ...(view.status ? { status: view.status } : {}),
    };
  }

  current(): Params {
    return this.params;
  }
}
