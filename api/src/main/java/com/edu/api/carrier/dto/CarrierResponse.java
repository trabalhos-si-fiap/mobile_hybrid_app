package com.edu.api.carrier.dto;

import com.edu.api.carrier.entity.CarrierStatus;

import java.math.BigDecimal;
import java.time.Instant;

public record CarrierResponse(

        Long id,
        String name,
        String location,
        String email,
        int averageDeliveryDays,
        BigDecimal rating,
        BigDecimal slaPercentage,
        CarrierStatus status,
        Instant createdAt,
        Instant updatedAt

) {}