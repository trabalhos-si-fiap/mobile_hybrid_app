package com.edu.api.chatbot.dto;

/** Exatamente um dos dois: o texto digitado ou o id da opção tocada. */
public record ChatbotReplyRequest(String text, String optionId) {}
