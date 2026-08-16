package com.edu.api.occurrence.dto;

import com.edu.api.occurrence.entity.OccurrenceStatus;
import jakarta.validation.constraints.NotNull;

public record UpdateOccurrenceStatusRequest(

        @NotNull
        OccurrenceStatus status

) {}