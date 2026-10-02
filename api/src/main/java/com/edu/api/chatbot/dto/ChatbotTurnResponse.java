package com.edu.api.chatbot.dto;

import com.edu.api.chatbot.entity.ChatbotState;

import java.util.List;

/** Um turno: a mensagem do usuário (se houver) seguida das do bot, e as opções do novo estado. */
public record ChatbotTurnResponse(
        Long conversationId,
        ChatbotState state,
        List<ChatbotMessageResponse> messages,
        List<ChatbotOptionResponse> options,
        ChatbotHandoffResponse handoff
) {}
