package com.edu.api.chatbot;

import com.edu.api.support.FullStackIntegration;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.springframework.http.HttpHeaders.AUTHORIZATION;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Regras de acesso do bot pela cadeia de segurança real. */
class ChatbotSecurityIT extends FullStackIntegration {

    @Test
    void theBotRequiresAuthentication() throws Exception {
        mockMvc.perform(post("/chatbot/conversations"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
        mockMvc.perform(post("/chatbot/conversations/1/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"text\":\"oi\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void staffCanTalkToTheBotToo() throws Exception {
        long agentUser = fx.userOf(fx.employee("ONLINE", "DESENVOLVEDOR"));

        mockMvc.perform(post("/chatbot/conversations").header(AUTHORIZATION, bearer(agentUser, "EMPLOYEE")))
                .andExpect(status().isCreated());
    }

    @Test
    void anotherUsersConversationIsNotFound() throws Exception {
        String opened = mockMvc.perform(post("/chatbot/conversations")
                        .header(AUTHORIZATION, bearer(fx.user("USER"), "USER")))
                .andReturn().getResponse().getContentAsString();
        long conversation = ((Number) JsonPath.read(opened, "$.conversationId")).longValue();

        mockMvc.perform(post("/chatbot/conversations/{id}/messages", conversation)
                        .header(AUTHORIZATION, bearer(fx.user("USER"), "USER"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"optionId\":\"human\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("NOT_FOUND"));
    }
}
