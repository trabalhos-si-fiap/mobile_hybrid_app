package com.edu.api.ticket.dto;

import com.edu.api.ticket.entity.TicketEventType;
import com.edu.api.ticket.entity.TicketStatus;

import java.time.Instant;

public record TicketEventResponse(
        Long id,
        TicketEventType type,
        TicketStatus fromStatus,
        TicketStatus toStatus,
        String employeeName,
        String detail,
        Instant createdAt
) {}
