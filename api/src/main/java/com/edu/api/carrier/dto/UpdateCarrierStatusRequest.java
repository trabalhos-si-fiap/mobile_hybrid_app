package com.edu.api.carrier.dto;

import com.edu.api.carrier.entity.CarrierStatus;
import jakarta.validation.constraints.NotNull;

public record UpdateCarrierStatusRequest(

        @NotNull
        CarrierStatus status

) {}