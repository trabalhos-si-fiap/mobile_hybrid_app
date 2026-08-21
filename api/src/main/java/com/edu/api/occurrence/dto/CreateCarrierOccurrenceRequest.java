package com.edu.api.occurrence.dto;

import com.edu.api.occurrence.entity.OccurrenceType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateCarrierOccurrenceRequest(

        @NotNull
        Long carrierId,

        @NotNull
        OccurrenceType type,

        @NotBlank
        @Size(max = 500)
        String description

) {}