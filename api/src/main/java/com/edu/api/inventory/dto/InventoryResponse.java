package com.edu.api.inventory.dto;

public record InventoryResponse(
        Long productId,
        String productName,
        String sku,
        int quantity,
        int minimumStock,
        String status
) {}