package com.edu.api.chatbot.dto;

/** Resposta rápida: id (segment:X, faq:N, menu, human, resolved, not_resolved) e rótulo do botão. */
public record ChatbotOptionResponse(String id, String label) {}
