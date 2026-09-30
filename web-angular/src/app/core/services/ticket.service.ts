import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

import {
  Attachment,
  QueueScope,
  Segment,
  SegmentOption,
  TicketDetail,
  TicketEvent,
  TicketMessage,
  TicketStatus,
  TicketSummary,
} from '../models/ticket.model';

@Injectable({ providedIn: 'root' })
export class TicketService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  queue(scope: QueueScope, status: TicketStatus | null): Observable<TicketSummary[]> {
    let params = new HttpParams().set('scope', scope);

    if (status) {
      params = params.set('status', status);
    }

    return this.http.get<TicketSummary[]>(`${this.apiUrl}/tickets/queue`, { params });
  }

  get(id: number): Observable<TicketDetail> {
    return this.http.get<TicketDetail>(`${this.apiUrl}/tickets/${id}`);
  }

  messages(id: number): Observable<TicketMessage[]> {
    return this.http.get<TicketMessage[]>(`${this.apiUrl}/tickets/${id}/messages`);
  }

  events(id: number): Observable<TicketEvent[]> {
    return this.http.get<TicketEvent[]>(`${this.apiUrl}/tickets/${id}/events`);
  }

  sendMessage(id: number, body: string, files: File[]): Observable<TicketMessage> {
    const form = new FormData();
    form.append('body', body);
    files.forEach((file) => form.append('files', file, file.name));

    return this.http.post<TicketMessage>(`${this.apiUrl}/tickets/${id}/messages`, form);
  }

  assume(id: number): Observable<TicketDetail> {
    return this.http.post<TicketDetail>(`${this.apiUrl}/tickets/${id}/assume`, null);
  }

  resolve(id: number): Observable<TicketDetail> {
    return this.http.post<TicketDetail>(`${this.apiUrl}/tickets/${id}/resolve`, null);
  }

  transfer(id: number, segment: Segment): Observable<TicketDetail> {
    return this.http.post<TicketDetail>(`${this.apiUrl}/tickets/${id}/transfer`, { segment });
  }

  raiseEngineeringAlert(id: number, reason: string): Observable<TicketDetail> {
    return this.http.post<TicketDetail>(`${this.apiUrl}/tickets/${id}/engineering-alert`, {
      reason,
    });
  }

  segments(): Observable<SegmentOption[]> {
    return this.http.get<SegmentOption[]>(`${this.apiUrl}/segments`);
  }

  /** A API exige o token, então o anexo vem pelo HttpClient (com o interceptor), como blob. */
  downloadAttachment(attachment: Attachment): Observable<Blob> {
    return this.http.get(`${this.apiUrl}${attachment.downloadPath}`, { responseType: 'blob' });
  }
}
