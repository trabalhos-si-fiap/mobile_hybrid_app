export interface Product {
  id: number;
  name: string;
  sku: string;
  description: string | null;
  minimumStock: number;
  active: boolean;
  price: number | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateProductRequest {
  name: string;
  sku: string;
  description?: string;
  minimumStock: number;
  initialQuantity: number;
  price?: number;
}

export interface UpdateProductRequest {
  name: string;
  sku: string;
  description?: string;
  minimumStock: number;
  active: boolean;
  price?: number;
}
