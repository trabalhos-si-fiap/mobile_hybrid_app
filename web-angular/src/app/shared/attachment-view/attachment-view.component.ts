import { Component, computed, DestroyRef, inject, input, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { map, Observable, of } from 'rxjs';

import { Attachment } from '../../core/models/ticket.model';
import { TicketService } from '../../core/services/ticket.service';
import { formatBytes, isImage } from '../../core/utils/attachment-rules';

@Component({
  selector: 'app-attachment-view',
  standalone: true,
  templateUrl: './attachment-view.component.html',
  styleUrl: './attachment-view.component.scss'
})
export class AttachmentViewComponent implements OnInit {
  private readonly tickets = inject(TicketService);
  private readonly destroyRef = inject(DestroyRef);

  readonly attachment = input.required<Attachment>();

  readonly previewUrl = signal<string | null>(null);
  readonly failed = signal(false);
  readonly image = computed(() => isImage(this.attachment().contentType));
  readonly size = computed(() => formatBytes(this.attachment().sizeBytes));

  private objectUrl: string | null = null;

  constructor() {
    this.destroyRef.onDestroy(() => {
      if (this.objectUrl) {
        URL.revokeObjectURL(this.objectUrl);
      }
    });
  }

  ngOnInit(): void {
    if (this.image()) {
      this.download()
        .pipe(takeUntilDestroyed(this.destroyRef))
        .subscribe({
          next: url => this.previewUrl.set(url),
          error: () => this.failed.set(true)
        });
    }
  }

  /** A aba nasce no próprio clique, para o bloqueador de pop-ups não barrar; a URL vem depois. */
  open(): void {
    const tab = window.open('', '_blank');
    if (tab) {
      tab.opener = null;
    }

    this.download()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: url => {
          this.failed.set(false);
          if (tab) {
            tab.location.href = url;
          } else {
            this.saveAs(url);
          }
        },
        error: () => {
          tab?.close();
          this.failed.set(true);
        }
      });
  }

  private download(): Observable<string> {
    if (this.objectUrl) {
      return of(this.objectUrl);
    }

    return this.tickets.downloadAttachment(this.attachment()).pipe(
      map(blob => {
        this.objectUrl = URL.createObjectURL(blob);
        return this.objectUrl;
      })
    );
  }

  /** Pop-up bloqueado mesmo assim: baixa o arquivo. */
  private saveAs(url: string): void {
    const link = document.createElement('a');
    link.href = url;
    link.download = this.attachment().fileName;
    link.click();
  }
}
