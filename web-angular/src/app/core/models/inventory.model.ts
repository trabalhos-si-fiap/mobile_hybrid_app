export type InventoryStatus = 'NORMAL' | 'LOW_STOCK' | 'OUT_OF_STOCK';

export interface InventoryItem {
  productId: number;
  productName: string;
  sku: string;
  quantity: number;
  minimumStock: number;
  status: InventoryStatus;
  updatedAt: string;
}

export interface InventoryPage {
  content: InventoryItem[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}

export interface InventorySummary {
  totalProducts: number;
  lowStock: number;
  outOfStock: number;
}

export interface AdjustInventoryRequest {
  quantity: number;
  reason: string;
}
