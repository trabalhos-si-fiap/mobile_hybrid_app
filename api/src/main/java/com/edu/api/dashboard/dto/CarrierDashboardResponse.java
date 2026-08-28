package com.edu.api.dashboard.dto;

import java.math.BigDecimal;

public record CarrierDashboardResponse(
        Long carrierId,
        String name,
        BigDecimal rating,
        BigDecimal slaPercentage,
        int averageDeliveryDays
) {
}