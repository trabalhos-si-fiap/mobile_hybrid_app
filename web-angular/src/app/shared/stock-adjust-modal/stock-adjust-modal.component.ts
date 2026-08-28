import {
  ChangeDetectorRef,
  Component,
  EventEmitter,
  inject,
  Input,
  OnInit,
  Output
} from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators
} from '@angular/forms';

import { InventoryItem } from '../../core/models/inventory.model';
import { InventoryService } from '../../core/services/inventory.service';

@Component({
  selector: 'app-stock-adjust-modal',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './stock-adjust-modal.component.html',
  styleUrl: './stock-adjust-modal.component.scss'
})
export class StockAdjustModalComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly inventoryService = inject(InventoryService);
  private readonly cdr = inject(ChangeDetectorRef);

  @Input({ required: true }) item!: InventoryItem;

  @Output() closed = new EventEmitter<void>();
  @Output() saved = new EventEmitter<void>();

  saving = false;
  errorMessage = '';

  readonly reasonOptions = [
    'Recebimento de lote',
    'Correção de inventário',
    'Devolução',
    'Perda ou avaria',
    'Saída manual',
    'Outro'
  ];

  readonly form = this.fb.nonNullable.group({
    quantity: [0, [Validators.required, Validators.min(0)]],
    reasonPreset: ['Recebimento de lote', Validators.required],
    observations: ['', Validators.maxLength(220)]
  });

  ngOnInit(): void {
    this.form.patchValue({
      quantity: this.item.quantity
    });
  }

  close(): void {
    if (!this.saving) {
      this.closed.emit();
    }
  }

  submit(): void {
    if (this.form.invalid || this.saving) {
      this.form.markAllAsTouched();
      return;
    }

    const { quantity, reasonPreset, observations } =
      this.form.getRawValue();

    const cleanObservation = observations.trim();
    const reason = cleanObservation
      ? `${reasonPreset}: ${cleanObservation}`
      : reasonPreset;

    this.saving = true;
    this.errorMessage = '';

    this.inventoryService
      .adjustInventory(this.item.productId, {
        quantity: Number(quantity),
        reason
      })
      .subscribe({
        next: () => {
          this.saving = false;
          this.cdr.markForCheck();
          this.saved.emit();
        },
        error: error => {
          this.saving = false;
          this.cdr.markForCheck();

          if (error?.status === 400) {
            this.errorMessage = 'Confira a quantidade e o motivo do ajuste.';
            return;
          }

          this.errorMessage = 'Não foi possível atualizar o estoque.';
        }
      });
  }

  onBackdropMouseDown(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.close();
    }
  }

  productImage(): string {
    const name = this.item.productName.toLowerCase();

    if (
      name.includes('bloco') ||
      name.includes('caneta') ||
      name.includes('kit')
    ) {
      return '/assets/images/product-blocks.png';
    }

    if (
      this.item.status === 'OUT_OF_STOCK' ||
      name.includes('tablet')
    ) {
      return '/assets/images/product-tablet.png';
    }

    return '/assets/images/product-book.png';
  }
}
