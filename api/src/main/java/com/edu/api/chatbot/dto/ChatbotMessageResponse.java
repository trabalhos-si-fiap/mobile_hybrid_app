package com.edu.api.chatbot.dto;

import com.edu.api.chatbot.entity.ChatbotSender;

import java.time.Instant;

public record ChatbotMessageResponse(Long id, ChatbotSender sender, String body, Instant createdAt) {}
