import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { of, throwError } from 'rxjs';

import { AppNotification } from '../../core/models/ticket.model';
import { NotificationService } from '../../core/services/notification.service';
import { aNotification } from '../../testing/test-data';
import { NotificationPanelComponent } from './notification-panel.component';

describe('NotificationPanelComponent', () => {
  let list: Mock;
  let markRead: Mock;
  let markAllRead: Mock;
  let router: Router;

  beforeEach(() => {
    list = vi.fn(() =>
      of([
        aNotification(),
        aNotification({ id: 901, ticketId: 13, read: true, title: 'Novo ticket na sua fila' })
      ])
    );
    markRead = vi.fn(() => of(undefined));
    markAllRead = vi.fn(() => of(undefined));
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: NotificationService, useValue: { list, markRead, markAllRead } }
      ]
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
  });

  async function render(): Promise<{ fixture: ComponentFixture<NotificationPanelComponent>; closed: Mock }> {
    const fixture = TestBed.createComponent(NotificationPanelComponent);
    const closed = vi.fn();
    fixture.componentInstance.closed.subscribe(closed);
    await fixture.whenStable();
    return { fixture, closed };
  }

  function items(fixture: ComponentFixture<NotificationPanelComponent>): HTMLButtonElement[] {
    return Array.from(fixture.nativeElement.querySelectorAll('button.item'));
  }

  it('lists the notifications with the unread ones highlighted', async () => {
    const { fixture } = await render();

    expect(items(fixture)).toHaveLength(2);
    expect(items(fixture)[0].classList).toContain('unread');
    expect(items(fixture)[1].classList).not.toContain('unread');
    expect(items(fixture)[0].textContent).toContain('O usuário respondeu no ticket #12.');
  });

  it('marks as read, opens the ticket and closes on click', async () => {
    const { fixture, closed } = await render();

    items(fixture)[0].click();

    expect(markRead).toHaveBeenCalledWith(aNotification());
    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
    expect(closed).toHaveBeenCalled();
  });

  it('marks a notification without ticket as read and stays open', async () => {
    list.mockReturnValue(of([aNotification({ ticketId: null })]));
    const { fixture, closed } = await render();

    items(fixture)[0].click();
    await fixture.whenStable();

    expect(markRead).toHaveBeenCalled();
    expect(router.navigate).not.toHaveBeenCalled();
    expect(closed).not.toHaveBeenCalled();
    expect(items(fixture)[0].classList).not.toContain('unread');
  });

  it('marks all as read', async () => {
    const { fixture } = await render();

    const button = Array.from<HTMLButtonElement>(fixture.nativeElement.querySelectorAll('button')).find(
      item => item.textContent?.trim() === 'Marcar todas como lidas'
    )!;
    button.click();
    await fixture.whenStable();

    expect(markAllRead).toHaveBeenCalled();
    expect(items(fixture).some(item => item.classList.contains('unread'))).toBe(false);
  });

  it('says when there is nothing', async () => {
    list.mockReturnValue(of([] as AppNotification[]));
    const { fixture } = await render();

    expect(fixture.nativeElement.textContent).toContain('Nenhuma notificação');
  });

  it('shows only the error, not the empty message, when loading fails', async () => {
    list.mockReturnValue(throwError(() => new Error('falha')));
    const { fixture } = await render();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('Não foi possível carregar as notificações.');
    expect(text).not.toContain('Nenhuma notificação');
  });
});
