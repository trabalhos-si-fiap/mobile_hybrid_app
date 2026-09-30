import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { anAttachment, fakeFile } from '../../testing/test-data';
import { TicketService } from './ticket.service';

describe('TicketService', () => {
  let service: TicketService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(TicketService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('lists the queue by scope, with the status only when given', () => {
    service.queue('mine', null).subscribe();
    const plain = http.expectOne((req) => req.url === '/api/v1/tickets/queue');
    expect(plain.request.params.get('scope')).toBe('mine');
    expect(plain.request.params.has('status')).toBe(false);
    plain.flush([]);

    service.queue('all', 'ABERTO').subscribe();
    const filtered = http.expectOne((req) => req.url === '/api/v1/tickets/queue');
    expect(filtered.request.params.get('scope')).toBe('all');
    expect(filtered.request.params.get('status')).toBe('ABERTO');
    filtered.flush([]);
  });

  it('reads the ticket, its messages and its events', () => {
    service.get(12).subscribe();
    service.messages(12).subscribe();
    service.events(12).subscribe();

    expect(http.expectOne('/api/v1/tickets/12').request.method).toBe('GET');
    expect(http.expectOne('/api/v1/tickets/12/messages').request.method).toBe('GET');
    expect(http.expectOne('/api/v1/tickets/12/events').request.method).toBe('GET');
  });

  it('sends a message as multipart with every file under "files"', () => {
    const files = [fakeFile('a.png', 'image/png', 10), fakeFile('b.pdf', 'application/pdf', 20)];

    service.sendMessage(12, 'Olá', files).subscribe();

    const request = http.expectOne('/api/v1/tickets/12/messages');
    expect(request.request.method).toBe('POST');
    const form = request.request.body as FormData;
    expect(form.get('body')).toBe('Olá');
    expect((form.getAll('files') as File[]).map((file) => file.name)).toEqual(['a.png', 'b.pdf']);
  });

  it('posts the quick actions', () => {
    service.assume(12).subscribe();
    service.resolve(12).subscribe();
    service.transfer(12, 'FEEDBACK_SUGESTAO').subscribe();
    service.raiseEngineeringAlert(12, 'Crash no checkout').subscribe();

    expect(http.expectOne('/api/v1/tickets/12/assume').request.method).toBe('POST');
    expect(http.expectOne('/api/v1/tickets/12/resolve').request.method).toBe('POST');
    expect(http.expectOne('/api/v1/tickets/12/transfer').request.body).toEqual({
      segment: 'FEEDBACK_SUGESTAO',
    });
    expect(http.expectOne('/api/v1/tickets/12/engineering-alert').request.body).toEqual({
      reason: 'Crash no checkout',
    });
  });

  it('lists the segments', () => {
    service.segments().subscribe();

    expect(http.expectOne('/api/v1/segments').request.method).toBe('GET');
  });

  it('downloads an attachment as a blob from the API base plus downloadPath', () => {
    service.downloadAttachment(anAttachment()).subscribe();

    const request = http.expectOne('/api/v1/tickets/12/attachments/3');
    expect(request.request.responseType).toBe('blob');
  });
});
