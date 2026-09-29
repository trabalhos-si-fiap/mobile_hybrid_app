package com.edu.api.ticket.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record EngineeringAlertRequest(@NotBlank @Size(max = 500) String reason) {}
