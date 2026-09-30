import {
  catchError,
  distinctUntilChanged,
  EMPTY,
  fromEvent,
  interval,
  map,
  Observable,
  of,
  startWith,
  switchMap
} from 'rxjs';

export type PollEvent<T> = { ok: true; value: T } | { ok: false; error: unknown };

/**
 * Busca na hora e depois a cada intervalo, pausando com a aba oculta.
 * reload$ busca na hora e reinicia o intervalo. Uma busca nova cancela a pendente,
 * então uma resposta atrasada nunca sobrescreve uma mais nova. Erros viram eventos
 * { ok: false } e não encerram o polling. Encerre com takeUntilDestroyed().
 */
export function poll<T>(
  source: () => Observable<T>,
  intervalMs: number,
  reload$: Observable<unknown> = EMPTY,
  doc: Document = document
): Observable<PollEvent<T>> {
  const visible$ = fromEvent(doc, 'visibilitychange').pipe(
    startWith(null),
    map(() => doc.visibilityState !== 'hidden'),
    distinctUntilChanged()
  );

  return visible$.pipe(
    switchMap(visible =>
      visible
        ? reload$.pipe(
            startWith(null),
            switchMap(() => interval(intervalMs).pipe(startWith(-1)))
          )
        : EMPTY
    ),
    switchMap(() =>
      source().pipe(
        map(value => ({ ok: true, value }) as PollEvent<T>),
        catchError(error => of({ ok: false, error } as PollEvent<T>))
      )
    )
  );
}
