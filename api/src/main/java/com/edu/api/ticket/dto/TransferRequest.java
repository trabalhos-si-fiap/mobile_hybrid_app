package com.edu.api.ticket.dto;

import com.edu.api.ticket.entity.Segment;
import jakarta.validation.constraints.NotNull;

public record TransferRequest(@NotNull Segment segment) {}
