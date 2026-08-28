import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { forkJoin, map, Observable, of, switchMap, tap } from 'rxjs';

import {
  AdjustInventoryRequest,
  InventoryItem,
  InventoryPage,
  InventorySummary
} from '../models/inventory.model';
import { DashboardService } from './dashboard.service';

@Injectable({ providedIn: 'root' })
export class InventoryService {
  private readonly http = inject(HttpClient);
  private readonly dashboardService = inject(DashboardService);
  private readonly apiUrl = '/api/v1';

  listInventory(
    page = 0,
    size = 3,
    search = '',
    lowStock = false
  ): Observable<InventoryPage> {
    let params = new HttpParams()
      .set('page', String(page))
      .set('size', String(size))
      .set('lowStock', String(lowStock));

    if (search.trim()) {
      params = params.set('search', search.trim());
    }

    return this.http.get<InventoryPage>(
      `${this.apiUrl}/inventory`,
      { params }
    );
  }

  adjustInventory(
    productId: number,
    request: AdjustInventoryRequest
  ): Observable<InventoryItem> {
    return this.http
      .patch<InventoryItem>(
        `${this.apiUrl}/inventory/${productId}`,
        request
      )
      .pipe(
        tap(() => this.dashboardService.invalidateCache())
      );
  }

  getSummary(): Observable<InventorySummary> {
    return forkJoin({
      dashboard: this.dashboardService.getDashboard(30),
      lowStockPages: this.getAllLowStockPages()
    }).pipe(
      map(({ dashboard, lowStockPages }) => {
        const lowStockItems = lowStockPages.flatMap(page => page.content);

        return {
          totalProducts: dashboard.operational.registeredProducts,
          lowStock: dashboard.operational.lowStockProducts,
          outOfStock: lowStockItems.filter(
            item => item.status === 'OUT_OF_STOCK'
          ).length
        };
      })
    );
  }

  private getAllLowStockPages(): Observable<InventoryPage[]> {
    return this.listInventory(0, 100, '', true).pipe(
      switchMap(firstPage => {
        if (firstPage.totalPages <= 1) {
          return of([firstPage]);
        }

        const requests: Observable<InventoryPage>[] = [];

        for (let page = 1; page < firstPage.totalPages; page++) {
          requests.push(
            this.listInventory(page, 100, '', true)
          );
        }

        return forkJoin(requests).pipe(
          map(rest => [firstPage, ...rest])
        );
      })
    );
  }
}
