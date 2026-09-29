package com.edu.api.ticket.dto;

public record AttachmentResponse(Long id, String fileName, String contentType, long sizeBytes, String downloadPath) {}
