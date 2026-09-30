import { inject, Injectable, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import {
  catchError,
  defer,
  map,
  Observable,
  of,
  retry,
  Subject,
  tap,
  throwError,
  timeout,
  timer
} from 'rxjs';

import { EmployeeMe, Presence } from '../models/ticket.model';
import { httpStatus, isTransientError } from '../utils/api-error';

const RETRY_DELAY_MS = 5000;
const LOGOUT_TIMEOUT_MS = 3000;

@Injectable({ providedIn: 'root' })
export class EmployeeService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  private readonly meState = signal<EmployeeMe | null | undefined>(undefined);
  private readonly presenceChanges = new Subject<Presence>();

  /** undefined: carregando; null: staff sem cadastro de atendente. */
  readonly me = this.meState.asReadonly();
  readonly presenceChanged$ = this.presenceChanges.asObservable();

  load(): Observable<EmployeeMe | null> {
    return defer(() => {
      this.meState.set(undefined);
      return this.http.get<EmployeeMe>(`${this.apiUrl}/employees/me`);
    }).pipe(
      retry({
        delay: error =>
          isTransientError(error) ? timer(RETRY_DELAY_MS) : throwError(() => error)
      }),
      // 403 aqui não é erro: é staff sem cadastro de atendente.
      catchError(error => (httpStatus(error) === 403 ? of(null) : throwError(() => error))),
      tap(me => this.meState.set(me))
    );
  }

  changePresence(presence: Presence): Observable<EmployeeMe> {
    return this.http
      .put<EmployeeMe>(`${this.apiUrl}/employees/me/presence`, { presence })
      .pipe(
        tap(me => {
          this.meState.set(me);
          this.presenceChanges.next(me.presence);
        })
      );
  }

  /** Antes de sair: OFFLINE, esperando no máximo 3 s. Uma falha não impede a saída. */
  goOffline(): Observable<void> {
    return this.http
      .put<EmployeeMe>(`${this.apiUrl}/employees/me/presence`, { presence: 'OFFLINE' })
      .pipe(
        timeout(LOGOUT_TIMEOUT_MS),
        map(() => undefined),
        catchError(() => of(undefined))
      );
  }

  clear(): void {
    this.meState.set(undefined);
  }
}
