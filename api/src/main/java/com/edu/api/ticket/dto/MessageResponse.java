package com.edu.api.ticket.dto;

import com.edu.api.ticket.entity.SenderType;

import java.time.Instant;
import java.util.List;

public record MessageResponse(
        Long id,
        SenderType senderType,
        String senderName,
        String body,
        List<AttachmentResponse> attachments,
        Instant createdAt
) {}
