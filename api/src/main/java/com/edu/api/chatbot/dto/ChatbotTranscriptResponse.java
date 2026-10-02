package com.edu.api.chatbot.dto;

import java.time.Instant;
import java.util.List;

public record ChatbotTranscriptResponse(Long conversationId, Instant startedAt, List<ChatbotMessageResponse> messages) {}
