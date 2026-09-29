package com.edu.api.ticket.dto;

import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketPriority;
import com.edu.api.ticket.entity.TicketStatus;

import java.time.Instant;

public record TicketSummaryResponse(
        Long id,
        Segment segment,
        String segmentLabel,
        TicketStatus status,
        TicketPriority priority,
        String slaStatus,
        Instant slaDueAt,
        String requesterName,
        String assigneeName,
        boolean engineeringAlert,
        Instant createdAt,
        Instant updatedAt
) {}
