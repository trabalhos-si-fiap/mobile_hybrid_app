package com.edu.api.chatbot.dto;

import com.edu.api.ticket.entity.Segment;

/** Rascunho do ticket na passagem para o atendente; segment é nulo se o usuário não escolheu nenhum. */
public record ChatbotHandoffResponse(Segment segment, String description) {}
