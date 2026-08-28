import { CommonModule } from '@angular/common';
import {
  ChangeDetectorRef,
  Component,
  EventEmitter,
  Input,
  OnInit,
  Output,
  inject
} from '@angular/core';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators
} from '@angular/forms';

import { ProductService } from '../../core/services/product.service';

export type ProductSaveMode = 'created' | 'updated';

@Component({
  selector: 'app-product-form-modal',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './product-form-modal.component.html',
  styleUrl: './product-form-modal.component.scss'
})
export class ProductFormModalComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly productService = inject(ProductService);
  private readonly cdr = inject(ChangeDetectorRef);

  @Input() productId: number | null = null;

  @Output() closed = new EventEmitter<void>();
  @Output() saved = new EventEmitter<ProductSaveMode>();

  loadingProduct = false;
  saving = false;
  errorMessage = '';

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.maxLength(150)]],
    sku: ['', [Validators.required, Validators.maxLength(60)]],
    description: ['', Validators.maxLength(500)],
    minimumStock: [0, [Validators.required, Validators.min(0)]],
    initialQuantity: [0, [Validators.required, Validators.min(0)]],
    price: [0, [Validators.required, Validators.min(0)]],
    active: [true]
  });

  get isEdit(): boolean {
    return this.productId !== null;
  }

  ngOnInit(): void {
    if (this.productId === null) {
      return;
    }

    this.loadingProduct = true;

    this.productService.getProduct(this.productId).subscribe({
      next: product => {
        this.form.patchValue({
          name: product.name,
          sku: product.sku,
          description: product.description ?? '',
          minimumStock: product.minimumStock,
          price: product.price ?? 0,
          active: product.active
        });

        this.loadingProduct = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.loadingProduct = false;
        this.errorMessage = 'Não foi possível carregar os dados do produto.';
        this.cdr.markForCheck();
      }
    });
  }

  setActive(active: boolean): void {
    this.form.controls.active.setValue(active);
  }

  close(): void {
    if (!this.saving) {
      this.closed.emit();
    }
  }

  submit(): void {
    if (this.loadingProduct || this.form.invalid || this.saving) {
      this.form.markAllAsTouched();
      return;
    }

    const value = this.form.getRawValue();
    this.saving = true;
    this.errorMessage = '';

    if (this.productId === null) {
      this.productService
        .createProduct({
          name: value.name.trim(),
          sku: value.sku.trim(),
          description: value.description.trim(),
          minimumStock: Number(value.minimumStock),
          initialQuantity: Number(value.initialQuantity),
          price: Number(value.price)
        })
        .subscribe({
          next: () => {
            this.saving = false;
            this.cdr.markForCheck();
            this.saved.emit('created');
          },
          error: () => {
            this.saving = false;
            this.errorMessage = 'Não foi possível adicionar o produto.';
            this.cdr.markForCheck();
          }
        });

      return;
    }

    this.productService
      .updateProduct(this.productId, {
        name: value.name.trim(),
        sku: value.sku.trim(),
        description: value.description.trim(),
        minimumStock: Number(value.minimumStock),
        price: Number(value.price),
        active: value.active
      })
      .subscribe({
        next: () => {
          this.saving = false;
          this.cdr.markForCheck();
          this.saved.emit('updated');
        },
        error: () => {
          this.saving = false;
          this.errorMessage = 'Não foi possível editar o produto.';
          this.cdr.markForCheck();
        }
      });
  }

  onBackdrop(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.close();
    }
  }
}
