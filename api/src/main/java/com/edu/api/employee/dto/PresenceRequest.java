package com.edu.api.employee.dto;

import com.edu.api.employee.entity.Presence;
import jakarta.validation.constraints.NotNull;

public record PresenceRequest(@NotNull Presence presence) {}
