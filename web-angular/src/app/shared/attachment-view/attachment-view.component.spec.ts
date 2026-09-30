import { afterEach, beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';

import { Attachment } from '../../core/models/ticket.model';
import { TicketService } from '../../core/services/ticket.service';
import { anAttachment, httpError } from '../../testing/test-data';
import { AttachmentViewComponent } from './attachment-view.component';

describe('AttachmentViewComponent', () => {
  let download: Mock;
  let createObjectURL: Mock;
  let revokeObjectURL: Mock;

  beforeEach(() => {
    download = vi.fn(() => of(new Blob(['x'])));
    createObjectURL = vi.fn(() => 'blob:preview');
    revokeObjectURL = vi.fn();
    Object.defineProperty(URL, 'createObjectURL', { value: createObjectURL, configurable: true, writable: true });
    Object.defineProperty(URL, 'revokeObjectURL', { value: revokeObjectURL, configurable: true, writable: true });
    TestBed.configureTestingModule({
      providers: [{ provide: TicketService, useValue: { downloadAttachment: download } }]
    });
  });

  afterEach(() => vi.restoreAllMocks());

  async function render(attachment: Attachment): Promise<ComponentFixture<AttachmentViewComponent>> {
    const fixture = TestBed.createComponent(AttachmentViewComponent);
    fixture.componentRef.setInput('attachment', attachment);
    await fixture.whenStable();
    return fixture;
  }

  const pdf = () =>
    anAttachment({ id: 4, fileName: 'laudo.pdf', contentType: 'application/pdf', sizeBytes: 1536 });

  it('shows an image as a thumbnail from the downloaded blob', async () => {
    const fixture = await render(anAttachment());

    const image: HTMLImageElement = fixture.nativeElement.querySelector('img');
    expect(download).toHaveBeenCalledWith(anAttachment());
    expect(image.getAttribute('src')).toBe('blob:preview');
    expect(image.getAttribute('alt')).toBe('print.png');
  });

  it('shows a PDF as a button with name and size, without downloading it upfront', async () => {
    const fixture = await render(pdf());

    const button: HTMLButtonElement = fixture.nativeElement.querySelector('button');
    expect(download).not.toHaveBeenCalled();
    expect(button.textContent).toContain('laudo.pdf');
    expect(button.textContent).toContain('2 KB');
  });

  it('opens the tab on the click and points it to the file once downloaded', async () => {
    const tab = { location: { href: '' }, opener: {}, close: vi.fn() };
    const open = vi.spyOn(window, 'open').mockReturnValue(tab as unknown as Window);
    const fixture = await render(pdf());

    fixture.nativeElement.querySelector('button').click();

    expect(open).toHaveBeenCalledWith('', '_blank');
    expect(tab.opener).toBeNull();
    expect(tab.location.href).toBe('blob:preview');
  });

  it('closes the tab and shows a failure when the download fails', async () => {
    const tab = { location: { href: '' }, opener: {}, close: vi.fn() };
    vi.spyOn(window, 'open').mockReturnValue(tab as unknown as Window);
    download.mockReturnValue(throwError(() => httpError(404)));
    const fixture = await render(pdf());

    fixture.nativeElement.querySelector('button').click();
    await fixture.whenStable();

    expect(tab.close).toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Não foi possível abrir o anexo.');
  });

  it('revokes the object URL when destroyed', async () => {
    const fixture = await render(anAttachment());

    fixture.destroy();

    expect(revokeObjectURL).toHaveBeenCalledWith('blob:preview');
  });

  it('shares the in-flight download so only one request and one createObjectURL happen', async () => {
    const subject = new Subject<Blob>();
    download.mockReturnValue(subject);
    const tab = { location: { href: '' }, opener: {}, close: vi.fn() };
    vi.spyOn(window, 'open').mockReturnValue(tab as unknown as Window);
    const fixture = await render(pdf());

    fixture.nativeElement.querySelector('button').click();
    fixture.nativeElement.querySelector('button').click();

    expect(download).toHaveBeenCalledTimes(1);

    subject.next(new Blob(['x']));
    await fixture.whenStable();

    expect(createObjectURL).toHaveBeenCalledTimes(1);
  });
});
