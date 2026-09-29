package com.edu.api.ticket.dto;

import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketChannel;
import com.edu.api.ticket.entity.TicketPriority;
import com.edu.api.ticket.entity.TicketQueue;
import com.edu.api.ticket.entity.TicketStatus;

import java.time.Instant;
import java.util.List;

public record TicketDetailResponse(
        Long id,
        Segment segment,
        String segmentLabel,
        TicketQueue queue,
        TicketStatus status,
        TicketPriority priority,
        TicketChannel channel,
        String description,
        String slaStatus,
        Instant slaDueAt,
        UserSummary requester,
        EmployeeSummary assignee,
        boolean engineeringAlert,
        String engineeringAlertReason,
        List<AttachmentResponse> attachments,
        Instant createdAt,
        Instant updatedAt,
        Instant assumedAt,
        Instant resolvedAt,
        Instant closedAt
) {}
