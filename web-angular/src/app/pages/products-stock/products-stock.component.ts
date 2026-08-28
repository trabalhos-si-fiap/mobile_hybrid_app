import {
  ChangeDetectorRef,
  Component,
  DestroyRef,
  inject,
  OnInit
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import {
  InventoryItem,
  InventoryPage,
  InventorySummary
} from '../../core/models/inventory.model';
import { InventoryService } from '../../core/services/inventory.service';
import { ProductFormModalComponent } from '../../shared/product-form-modal/product-form-modal.component';
import { StockAdjustModalComponent } from '../../shared/stock-adjust-modal/stock-adjust-modal.component';
import { SuccessToastComponent } from '../../shared/success-toast/success-toast.component';

@Component({
  selector: 'app-products-stock',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    ProductFormModalComponent,
    StockAdjustModalComponent,
    SuccessToastComponent
  ],
  templateUrl: './products-stock.component.html',
  styleUrl: './products-stock.component.scss'
})
export class ProductsStockComponent implements OnInit {
  private readonly inventoryService = inject(InventoryService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly cdr = inject(ChangeDetectorRef);

  readonly searchControl = new FormControl('', { nonNullable: true });

  inventoryPage: InventoryPage | null = null;
  summary: InventorySummary = {
    totalProducts: 0,
    lowStock: 0,
    outOfStock: 0
  };

  page = 0;
  readonly pageSize = 3;
  lowStockOnly = false;

  loadingTable = false;
  loadingSummary = false;

  selectedStockItem: InventoryItem | null = null;
  productFormOpen = false;
  editingProductId: number | null = null;

  successMessage = '';
  private successTimer: number | null = null;

  ngOnInit(): void {
    this.loadSummary();
    this.loadPage();

    this.searchControl.valueChanges
      .pipe(
        debounceTime(300),
        distinctUntilChanged(),
        takeUntilDestroyed(this.destroyRef)
      )
      .subscribe(() => {
        this.page = 0;
        this.loadPage();
      });
  }

  loadPage(): void {
    this.loadingTable = true;

    this.inventoryService
      .listInventory(
        this.page,
        this.pageSize,
        this.searchControl.value,
        this.lowStockOnly
      )
      .subscribe({
        next: response => {
          this.inventoryPage = response;
          this.loadingTable = false;
          this.cdr.markForCheck();
        },
        error: () => {
          this.loadingTable = false;
          this.cdr.markForCheck();
        }
      });
  }

  loadSummary(): void {
    this.loadingSummary = true;

    this.inventoryService.getSummary().subscribe({
      next: summary => {
        this.summary = summary;
        this.loadingSummary = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.loadingSummary = false;
        this.cdr.markForCheck();
      }
    });
  }

  openNewProduct(): void {
    this.editingProductId = null;
    this.productFormOpen = true;
  }

  openEditProduct(item: InventoryItem): void {
    this.editingProductId = item.productId;
    this.productFormOpen = true;
  }

  closeProductForm(): void {
    this.productFormOpen = false;
    this.editingProductId = null;
  }

  productSaved(mode: 'created' | 'updated'): void {
    this.closeProductForm();
    this.page = 0;
    this.loadPage();
    this.loadSummary();

    this.showSuccess(
      mode === 'created'
        ? 'Produto adicionado com sucesso'
        : 'Produto editado com sucesso'
    );
  }

  openAdjust(item: InventoryItem): void {
    this.selectedStockItem = item;
  }

  closeAdjust(): void {
    this.selectedStockItem = null;
  }

  afterAdjusted(): void {
    this.selectedStockItem = null;
    this.loadPage();
    this.loadSummary();
  }

  toggleLowStock(event: Event): void {
    this.lowStockOnly = (event.target as HTMLInputElement).checked;
    this.page = 0;
    this.loadPage();
  }

  previousPage(): void {
    if (this.page <= 0) return;
    this.page--;
    this.loadPage();
  }

  nextPage(): void {
    const totalPages = this.inventoryPage?.totalPages ?? 0;
    if (this.page + 1 >= totalPages) return;

    this.page++;
    this.loadPage();
  }

  goToDisplayPage(displayPage: number): void {
    this.page = displayPage - 1;
    this.loadPage();
  }

  statusLabel(item: InventoryItem): string {
    switch (item.status) {
      case 'LOW_STOCK':
        return 'Baixo';
      case 'OUT_OF_STOCK':
        return 'Esgotado';
      default:
        return 'Adequado';
    }
  }

  statusClass(item: InventoryItem): string {
    switch (item.status) {
      case 'LOW_STOCK':
        return 'low';
      case 'OUT_OF_STOCK':
        return 'out';
      default:
        return 'normal';
    }
  }

  productImage(item: InventoryItem): string {
    const name = item.productName.toLowerCase();

    if (
      name.includes('bloco') ||
      name.includes('caneta') ||
      name.includes('kit')
    ) {
      return '/assets/images/product-blocks.png';
    }

    if (
      item.status === 'OUT_OF_STOCK' ||
      name.includes('tablet')
    ) {
      return '/assets/images/product-tablet.png';
    }

    return '/assets/images/product-book.png';
  }

  get displayPages(): number[] {
    const total = this.inventoryPage?.totalPages ?? 0;
    if (total <= 0) return [];

    const current = this.page + 1;

    if (total === 1) return [1];
    if (current === total) return [Math.max(1, current - 1), current];

    return [current, current + 1];
  }

  get startResult(): number {
    const total = this.inventoryPage?.totalElements ?? 0;
    return total === 0 ? 0 : this.page * this.pageSize + 1;
  }

  get endResult(): number {
    const total = this.inventoryPage?.totalElements ?? 0;
    return Math.min((this.page + 1) * this.pageSize, total);
  }

  get totalResults(): number {
    return this.inventoryPage?.totalElements ?? 0;
  }

  get hasPrevious(): boolean {
    return this.page > 0;
  }

  get hasNext(): boolean {
    return this.page + 1 < (this.inventoryPage?.totalPages ?? 0);
  }

  private showSuccess(message: string): void {
    this.successMessage = message;

    if (this.successTimer !== null) {
      window.clearTimeout(this.successTimer);
    }

    this.successTimer = window.setTimeout(() => {
      this.successMessage = '';
      this.successTimer = null;
      this.cdr.markForCheck();
    }, 3200);

    this.cdr.markForCheck();
  }
}
