package com.edu.api.dashboard.dto;

public record LowStockProductResponse(
        Long productId,
        String productName,
        String sku,
        int currentQuantity,
        int minimumStock,
        String status
) {
}