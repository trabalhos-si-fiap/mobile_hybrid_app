package com.edu.api.dashboard.dto;

import java.util.List;

public record OperationalDashboardResponse(
        long registeredProducts,
        long lowStockProducts,
        long activeCarriers,
        long openOccurrences,
        List<LowStockProductResponse> lowStock,
        List<CarrierDashboardResponse> carriers,
        List<RecentOccurrenceResponse> recentOccurrences
) {
}