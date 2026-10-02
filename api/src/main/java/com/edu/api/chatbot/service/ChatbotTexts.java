package com.edu.api.chatbot.service;

/** Falas e rótulos do Mentor Edu. */
final class ChatbotTexts {

    static final String HUMAN_LABEL = "Falar com atendente";
    static final String OTHER_SUBJECT_LABEL = "Outro assunto";
    static final String RESOLVED_LABEL = "Resolveu";
    static final String NOT_RESOLVED_LABEL = "Não resolveu";

    static final String DID_IT_HELP = "Isso resolveu sua dúvida?";
    static final String NOT_UNDERSTOOD = "Não entendi. Pode explicar de outro jeito ou escolher uma opção?";
    static final String OTHER_SUBJECT = "Certo. Sobre o que você precisa de ajuda?";
    static final String RESOLVED = "Que bom! Se precisar, é só chamar.";
    static final String HANDOFF =
            "Vou te passar para um atendente. Revise o pedido, anexe evidências se tiver e envie.";
    static final String HANDOFF_AFTER_MISSES = "Não consegui entender. " + HANDOFF;
    static final String QUESTION_PREFIX = "Dúvida: ";

    private ChatbotTexts() {
    }

    static String greeting(String fullName) {
        String firstName = fullName.strip().split("\\s+")[0];
        return "Olá, " + firstName + "! Sou o Mentor Edu, o assistente do Edu. Sobre o que você precisa de ajuda?";
    }

    static String segmentChosen(String segmentLabel) {
        return "Estas são as dúvidas mais comuns sobre " + segmentLabel + ". Escolha uma ou escreva a sua.";
    }
}
