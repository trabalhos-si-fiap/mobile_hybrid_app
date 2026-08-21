package com.edu.api.carrier.dto;

import com.edu.api.carrier.entity.CarrierStatus;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record CarrierRequest(

        @NotBlank
        @Size(max = 150)
        String name,

        @NotBlank
        @Size(max = 150)
        String location,

        @NotBlank
        @Email
        @Size(max = 254)
        String email,

        @Min(0)
        int averageDeliveryDays,

        @NotNull
        @DecimalMin("0.0")
        @DecimalMax("5.0")
        BigDecimal rating,

        @NotNull
        @DecimalMin("0.0")
        @DecimalMax("100.0")
        BigDecimal slaPercentage,

        @NotNull
        CarrierStatus status

) {}