package com.edu.api.chatbot;

import com.edu.api.support.FullStackIntegration;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.contains;
import static org.springframework.http.HttpHeaders.AUTHORIZATION;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Da passagem do bot ao ticket CHATBOT_IA, e a transcrição no ticket, via HTTP com JWT reais. */
class ChatbotTicketIT extends FullStackIntegration {

    private long startConversation(String token) throws Exception {
        String started = mockMvc.perform(post("/chatbot/conversations").header(AUTHORIZATION, token))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(started, "$.conversationId")).longValue();
    }

    private ResultActions send(String token, long conversation, String json) throws Exception {
        return mockMvc.perform(post("/chatbot/conversations/{id}/messages", conversation)
                .header(AUTHORIZATION, token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json));
    }

    /** Início → segmento → "Falar com atendente". */
    private long handedOff(String token) throws Exception {
        long conversation = startConversation(token);
        send(token, conversation, "{\"optionId\":\"segment:PROBLEMA_PEDIDO\"}").andExpect(status().isOk());
        send(token, conversation, "{\"optionId\":\"human\"}")
                .andExpect(jsonPath("$.state").value("ENCAMINHAMENTO"));
        return conversation;
    }

    private ResultActions open(String token, Long conversation) throws Exception {
        var request = multipart("/tickets")
                .param("segment", "PROBLEMA_PEDIDO")
                .param("description", "Meu pedido chegou incompleto")
                .header(AUTHORIZATION, token);
        if (conversation != null) {
            request.param("chatbotConversationId", String.valueOf(conversation));
        }
        return mockMvc.perform(request);
    }

    private static long id(ResultActions opened) throws Exception {
        return ((Number) JsonPath.read(opened.andReturn().getResponse().getContentAsString(), "$.id")).longValue();
    }

    @Test
    void aHandoffOpensAChatbotTicketWithTheTranscript() throws Exception {
        long agent = fx.employee("ONLINE", "GESTAO_ENTREGAS");
        String userToken = bearer(fx.user("USER"), "USER");
        long conversation = handedOff(userToken);

        long ticket = id(open(userToken, conversation)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.channel").value("CHATBOT_IA"))
                .andExpect(jsonPath("$.status").value("EM_FILA"))
                .andExpect(jsonPath("$.assignee.id").value(agent)));

        mockMvc.perform(get("/tickets/{id}/chatbot-conversation", ticket).header(AUTHORIZATION, userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.conversationId").value(conversation))
                .andExpect(jsonPath("$.startedAt").isNotEmpty())
                .andExpect(jsonPath("$.messages[*].sender", contains("BOT", "USER", "BOT", "USER", "BOT")))
                .andExpect(jsonPath("$.messages[1].body").value("Problemas com pedido"))
                .andExpect(jsonPath("$.messages[3].body").value("Falar com atendente"));
        mockMvc.perform(get("/tickets/{id}/chatbot-conversation", ticket)
                        .header(AUTHORIZATION, bearer(fx.userOf(agent), "EMPLOYEE")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.messages.length()").value(5));

        flush();
        assertThat(fx.count("SELECT COUNT(*) FROM chatbot_conversations WHERE id = ? AND ticket_id = ?"
                + " AND state = 'ENCAMINHADA' AND finished_at IS NOT NULL", conversation, ticket)).isEqualTo(1);
    }

    @Test
    void withoutAConversationTheTicketIsAppAndHasNoTranscript() throws Exception {
        String token = bearer(fx.user("USER"), "USER");

        long ticket = id(open(token, null)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.channel").value("APP")));

        mockMvc.perform(get("/tickets/{id}/chatbot-conversation", ticket).header(AUTHORIZATION, token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("NOT_FOUND"));
    }

    @Test
    void aConversationOpensOnlyOneTicket() throws Exception {
        long requester = fx.user("USER");
        String token = bearer(requester, "USER");
        long conversation = handedOff(token);
        open(token, conversation).andExpect(status().isCreated());

        open(token, conversation)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("CONFLICT"));

        assertThat(fx.count("SELECT COUNT(*) FROM tickets WHERE user_id = ?", requester)).isEqualTo(1);
    }

    @Test
    void aConversationBeforeTheHandoffCannotOpenATicket() throws Exception {
        long requester = fx.user("USER");
        String token = bearer(requester, "USER");
        long conversation = startConversation(token);

        open(token, conversation)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("CONFLICT"));

        assertThat(fx.count("SELECT COUNT(*) FROM tickets WHERE user_id = ?", requester)).isZero();
    }

    @Test
    void anotherUsersConversationIsNotFound() throws Exception {
        long conversation = handedOff(bearer(fx.user("USER"), "USER"));
        long stranger = fx.user("USER");

        open(bearer(stranger, "USER"), conversation)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("NOT_FOUND"));

        assertThat(fx.count("SELECT COUNT(*) FROM tickets WHERE user_id = ?", stranger)).isZero();
    }

    @Test
    void strangersCannotReadTheTranscript() throws Exception {
        String token = bearer(fx.user("USER"), "USER");
        long ticket = id(open(token, handedOff(token)).andExpect(status().isCreated()));

        mockMvc.perform(get("/tickets/{id}/chatbot-conversation", ticket)
                        .header(AUTHORIZATION, bearer(fx.user("USER"), "USER")))
                .andExpect(status().isNotFound());
    }
}
