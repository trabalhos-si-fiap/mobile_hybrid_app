import { describe, expect, it } from 'vitest';

import { httpError } from '../../testing/test-data';
import {
  actionErrorMessage,
  apiErrorMessage,
  FORBIDDEN_ERROR,
  GENERIC_ACTION_ERROR,
  httpStatus,
  isTransientError,
} from './api-error';

describe('api-error', () => {
  it('prefers the message field of the ApiErrorResponse', () => {
    expect(apiErrorMessage(httpError(409, 'Ticket 12 está fechado'), 'x')).toBe(
      'Ticket 12 está fechado',
    );
  });

  it('falls back when there is no usable message', () => {
    expect(apiErrorMessage(httpError(409), 'fallback')).toBe('fallback');
    expect(apiErrorMessage(httpError(409, '   '), 'fallback')).toBe('fallback');
    expect(apiErrorMessage(new Error('boom'), 'fallback')).toBe('fallback');
  });

  it('reads the status, with 0 for anything that is not an HTTP error', () => {
    expect(httpStatus(httpError(404))).toBe(404);
    expect(httpStatus(new Error('boom'))).toBe(0);
  });

  it('treats network failures and 5xx as transient', () => {
    expect(isTransientError(httpError(0))).toBe(true);
    expect(isTransientError(httpError(503))).toBe(true);
    expect(isTransientError(httpError(409))).toBe(false);
  });

  it('maps a failed action to the message of the error table', () => {
    expect(actionErrorMessage(httpError(0))).toBe(GENERIC_ACTION_ERROR);
    expect(actionErrorMessage(httpError(500, 'Erro interno'))).toBe(GENERIC_ACTION_ERROR);
    expect(actionErrorMessage(httpError(403))).toBe(FORBIDDEN_ERROR);
    expect(actionErrorMessage(httpError(403, 'Somente ADMIN'))).toBe('Somente ADMIN');
    expect(actionErrorMessage(httpError(409, 'Ticket 12 está fechado'))).toBe(
      'Ticket 12 está fechado',
    );
    expect(GENERIC_ACTION_ERROR).toBe('Não foi possível concluir. Tente de novo.');
    expect(FORBIDDEN_ERROR).toBe('Você não tem permissão para esta ação.');
  });
});
