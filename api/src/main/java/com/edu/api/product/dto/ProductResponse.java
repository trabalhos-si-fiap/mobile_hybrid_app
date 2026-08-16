package com.edu.api.product.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record ProductResponse(
        Long id,
        String name,
        String sku,
        String description,
        int minimumStock,
        BigDecimal price,
        boolean active,
        Instant createdAt,
        Instant updatedAt
) {}