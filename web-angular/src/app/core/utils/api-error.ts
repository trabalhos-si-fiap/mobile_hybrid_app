import { HttpErrorResponse } from '@angular/common/http';

import { ApiErrorResponse } from '../models/ticket.model';

export const GENERIC_ACTION_ERROR = 'Não foi possível concluir. Tente de novo.';
export const FORBIDDEN_ERROR = 'Você não tem permissão para esta ação.';

export function httpStatus(error: unknown): number {
  return error instanceof HttpErrorResponse ? error.status : 0;
}

/** Falha de rede (status 0) ou 5xx: vale tentar de novo. */
export function isTransientError(error: unknown): boolean {
  const status = httpStatus(error);
  return status === 0 || status >= 500;
}

/** O campo message do ApiErrorResponse, quando existe; senão, o texto dado. */
export function apiErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof HttpErrorResponse) {
    const body = error.error as ApiErrorResponse | null;
    if (body && typeof body.message === 'string' && body.message.trim()) {
      return body.message;
    }
  }
  return fallback;
}

/** Texto do aviso para uma ação que falhou (tabela de erros da spec). */
export function actionErrorMessage(error: unknown): string {
  if (isTransientError(error)) {
    return GENERIC_ACTION_ERROR;
  }
  if (httpStatus(error) === 403) {
    return apiErrorMessage(error, FORBIDDEN_ERROR);
  }
  return apiErrorMessage(error, GENERIC_ACTION_ERROR);
}
