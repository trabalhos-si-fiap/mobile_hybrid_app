package com.edu.api.inventory.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AdjustInventoryRequest(

        @Min(0)
        int quantity,

        @NotBlank
        @Size(max = 300)
        String reason

) {}