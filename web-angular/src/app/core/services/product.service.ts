import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import {
  CreateProductRequest,
  Product,
  UpdateProductRequest
} from '../models/product.model';
import { DashboardService } from './dashboard.service';

@Injectable({ providedIn: 'root' })
export class ProductService {
  private readonly http = inject(HttpClient);
  private readonly dashboardService = inject(DashboardService);
  private readonly apiUrl = '/api/v1';

  getProduct(productId: number): Observable<Product> {
    return this.http.get<Product>(
      `${this.apiUrl}/products/${productId}`
    );
  }

  createProduct(request: CreateProductRequest): Observable<Product> {
    return this.http
      .post<Product>(`${this.apiUrl}/products`, request)
      .pipe(
        tap(() => this.dashboardService.invalidateCache())
      );
  }

  updateProduct(
    productId: number,
    request: UpdateProductRequest
  ): Observable<Product> {
    return this.http
      .put<Product>(
        `${this.apiUrl}/products/${productId}`,
        request
      )
      .pipe(
        tap(() => this.dashboardService.invalidateCache())
      );
  }
}
