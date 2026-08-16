package com.edu.api.occurrence.dto;

import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.entity.OccurrenceType;

import java.time.Instant;

public record CarrierOccurrenceResponse(

        Long id,

        Long carrierId,

        String carrierName,

        OccurrenceType type,

        String description,

        OccurrenceStatus status,

        Instant createdAt,

        Instant resolvedAt

) {}