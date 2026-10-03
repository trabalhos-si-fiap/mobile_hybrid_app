import { describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';

import { QueueParamsService } from './queue-params.service';

describe('QueueParamsService', () => {
  it('starts without params', () => {
    expect(TestBed.inject(QueueParamsService).current()).toEqual({});
  });

  it('remembers the tab and the status, dropping the ones that are not set', () => {
    const service = TestBed.inject(QueueParamsService);

    service.remember({ aba: 'skills', status: 'EM_FILA' });
    expect(service.current()).toEqual({ aba: 'skills', status: 'EM_FILA' });

    service.remember({ aba: 'todos', status: null });
    expect(service.current()).toEqual({ aba: 'todos' });

    service.remember({ aba: null, status: null });
    expect(service.current()).toEqual({});
  });
});
