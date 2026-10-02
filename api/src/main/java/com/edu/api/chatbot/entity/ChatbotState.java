package com.edu.api.chatbot.entity;

/**
 * Estados da conversa. INICIO, SEGMENTO e CONFIRMACAO aceitam mensagens;
 * ENCAMINHAMENTO espera o ticket; RESOLVIDA e ENCAMINHADA são finais.
 */
public enum ChatbotState {
    INICIO,
    SEGMENTO,
    CONFIRMACAO,
    ENCAMINHAMENTO,
    RESOLVIDA,
    ENCAMINHADA
}
