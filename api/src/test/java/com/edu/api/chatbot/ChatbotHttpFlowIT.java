package com.edu.api.chatbot;

import com.edu.api.support.ChatbotFixtures;
import com.edu.api.support.FullStackIntegration;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.http.HttpHeaders.AUTHORIZATION;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** O Mentor Edu pela HTTP, com JWT e a FN_CHATBOT_RESPOSTA reais. */
class ChatbotHttpFlowIT extends FullStackIntegration {

    private ChatbotFixtures bot;

    @BeforeEach
    void createBotFixtures() {
        bot = new ChatbotFixtures(jdbc);
    }

    private long start(String token) throws Exception {
        String body = mockMvc.perform(post("/chatbot/conversations").header(AUTHORIZATION, token))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.conversationId")).longValue();
    }

    private ResultActions send(String token, long conversationId, String json) throws Exception {
        return mockMvc.perform(post("/chatbot/conversations/{id}/messages", conversationId)
                .header(AUTHORIZATION, token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json));
    }

    @Test
    void answersAQuestionFromTheMenuAndEndsResolved() throws Exception {
        long deadline = bot.faq("PROBLEMA_PEDIDO", 1, "Qual o prazo de entrega?", "De 3 a 7 dias úteis.",
                "prazo", "entreg");
        String token = bearer(fx.user("USER"), "USER");

        String started = mockMvc.perform(post("/chatbot/conversations").header(AUTHORIZATION, token))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.state").value("INICIO"))
                .andExpect(jsonPath("$.messages[0].body").value(
                        "Olá, Pessoa! Sou o Mentor Edu, o assistente do Edu. Sobre o que você precisa de ajuda?"))
                .andExpect(jsonPath("$.options[*].id", contains("segment:DEFEITO_APP", "segment:PROBLEMA_PEDIDO",
                        "segment:FEEDBACK_SUGESTAO", "human")))
                .andReturn().getResponse().getContentAsString();
        long conversation = ((Number) JsonPath.read(started, "$.conversationId")).longValue();

        send(token, conversation, "{\"optionId\":\"segment:PROBLEMA_PEDIDO\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("SEGMENTO"))
                .andExpect(jsonPath("$.messages[0].sender").value("USER"))
                .andExpect(jsonPath("$.messages[0].body").value("Problemas com pedido"))
                .andExpect(jsonPath("$.options[*].id", contains("faq:" + deadline, "menu", "human")));

        send(token, conversation, "{\"optionId\":\"faq:" + deadline + "\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("CONFIRMACAO"))
                .andExpect(jsonPath("$.messages[1].body").value("De 3 a 7 dias úteis."))
                .andExpect(jsonPath("$.options[*].id", contains("resolved", "not_resolved")));

        send(token, conversation, "{\"optionId\":\"resolved\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("RESOLVIDA"))
                .andExpect(jsonPath("$.options").isEmpty())
                .andExpect(jsonPath("$.handoff").value(nullValue()));

        flush();
        assertThat(fx.count("SELECT COUNT(*) FROM chatbot_messages WHERE conversation_id = ?", conversation))
                .isEqualTo(8);
        assertThat(fx.count("SELECT COUNT(*) FROM chatbot_conversations WHERE id = ? AND state = 'RESOLVIDA'"
                + " AND finished_at IS NOT NULL", conversation)).isEqualTo(1);
    }

    @Test
    void matchesTypedTextWithTheFaq() throws Exception {
        long tracking = bot.faq("PROBLEMA_PEDIDO", 3, "Como rastrear o meu pedido?",
                "Acompanhe pelo código de rastreio.", "rastre", "transportador");
        String token = bearer(fx.user("USER"), "USER");
        long conversation = start(token);

        send(token, conversation, "{\"text\":\"Quero RASTREAR meu pedido\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("CONFIRMACAO"))
                .andExpect(jsonPath("$.messages[*].sender", contains("USER", "BOT", "BOT")))
                .andExpect(jsonPath("$.messages[1].body").value("Acompanhe pelo código de rastreio."));

        flush();
        assertThat(fx.count("SELECT COUNT(*) FROM chatbot_messages WHERE conversation_id = ? AND faq_id = ?",
                conversation, tracking)).isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM chatbot_conversations WHERE id = ? AND segment = 'PROBLEMA_PEDIDO'",
                conversation)).isEqualTo(1);
    }

    @Test
    void handsOffAndThenRefusesNewMessages() throws Exception {
        String token = bearer(fx.user("USER"), "USER");
        long conversation = start(token);
        send(token, conversation, "{\"optionId\":\"segment:DEFEITO_APP\"}").andExpect(status().isOk());

        send(token, conversation, "{\"optionId\":\"human\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("ENCAMINHAMENTO"))
                .andExpect(jsonPath("$.options").isEmpty())
                .andExpect(jsonPath("$.handoff.segment").value("DEFEITO_APP"))
                .andExpect(jsonPath("$.handoff.description").value(""));

        send(token, conversation, "{\"text\":\"Ainda está aí?\"}")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("CONFLICT"));
    }

    @Test
    void rejectsAnOptionTheStateDoesNotOffer() throws Exception {
        String token = bearer(fx.user("USER"), "USER");
        long conversation = start(token);

        send(token, conversation, "{\"optionId\":\"resolved\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"));
        send(token, conversation, "{\"text\":\"" + "x".repeat(501) + "\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"));
    }
}
