package com.edu.api.dashboard.dto;

import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.entity.OccurrenceType;

import java.time.Instant;

public record RecentOccurrenceResponse(
        Long occurrenceId,
        OccurrenceType type,
        String carrierName,
        Instant createdAt,
        OccurrenceStatus status
) {
}