package com.edu.api.chatbot.controller;

import com.edu.api.chatbot.dto.ChatbotHandoffResponse;
import com.edu.api.chatbot.dto.ChatbotMessageResponse;
import com.edu.api.chatbot.dto.ChatbotOptionResponse;
import com.edu.api.chatbot.dto.ChatbotReplyRequest;
import com.edu.api.chatbot.dto.ChatbotTurnResponse;
import com.edu.api.chatbot.entity.ChatbotSender;
import com.edu.api.chatbot.entity.ChatbotState;
import com.edu.api.chatbot.service.ChatbotService;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.shared.exception.ValidationException;
import com.edu.api.support.ControllerSliceTest;
import com.edu.api.support.WithAuthenticatedUser;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.time.Instant;
import java.util.List;

import static org.hamcrest.Matchers.nullValue;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ControllerSliceTest(ChatbotController.class)
@WithAuthenticatedUser
class ChatbotControllerTest {

    private static final AuthenticatedUser USER = new AuthenticatedUser(1L, "usuario@edu.com", "USER");
    private static final Instant AT = Instant.parse("2030-01-01T12:00:00Z");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ChatbotService chatbot;

    private ResultActions send(String json) throws Exception {
        return mockMvc.perform(post("/chatbot/conversations/42/messages")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json));
    }

    @Test
    void startsAConversation() throws Exception {
        when(chatbot.start(USER)).thenReturn(new ChatbotTurnResponse(42L, ChatbotState.INICIO,
                List.of(new ChatbotMessageResponse(1L, ChatbotSender.BOT, "Olá, Usuário!", AT)),
                List.of(new ChatbotOptionResponse("segment:DEFEITO_APP", "Defeito no App / Problemas com App"),
                        new ChatbotOptionResponse("human", "Falar com atendente")),
                null));

        mockMvc.perform(post("/chatbot/conversations"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.conversationId").value(42))
                .andExpect(jsonPath("$.state").value("INICIO"))
                .andExpect(jsonPath("$.messages[0].id").value(1))
                .andExpect(jsonPath("$.messages[0].sender").value("BOT"))
                .andExpect(jsonPath("$.messages[0].body").value("Olá, Usuário!"))
                .andExpect(jsonPath("$.messages[0].createdAt").value("2030-01-01T12:00:00Z"))
                .andExpect(jsonPath("$.options[0].id").value("segment:DEFEITO_APP"))
                .andExpect(jsonPath("$.options[1].label").value("Falar com atendente"))
                .andExpect(jsonPath("$.handoff").value(nullValue()));
    }

    @Test
    void returnsTheHandoffDraft() throws Exception {
        when(chatbot.reply(USER, 42L, new ChatbotReplyRequest(null, "human")))
                .thenReturn(new ChatbotTurnResponse(42L, ChatbotState.ENCAMINHAMENTO,
                        List.of(new ChatbotMessageResponse(2L, ChatbotSender.USER, "Falar com atendente", AT),
                                new ChatbotMessageResponse(3L, ChatbotSender.BOT, "Vou te passar para um atendente.", AT)),
                        List.of(), new ChatbotHandoffResponse(null, "")));

        send("{\"optionId\":\"human\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("ENCAMINHAMENTO"))
                .andExpect(jsonPath("$.messages[0].sender").value("USER"))
                .andExpect(jsonPath("$.options").isEmpty())
                .andExpect(jsonPath("$.handoff.segment").value(nullValue()))
                .andExpect(jsonPath("$.handoff.description").value(""));
    }

    @Test
    void reportsAnInvalidMessageAsBadRequest() throws Exception {
        when(chatbot.reply(USER, 42L, new ChatbotReplyRequest("Qual o prazo?", "human")))
                .thenThrow(new ValidationException("Envie text ou optionId, um dos dois"));

        send("{\"text\":\"Qual o prazo?\",\"optionId\":\"human\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.message").value("Envie text ou optionId, um dos dois"));
    }

    @Test
    void hidesAnotherUsersConversation() throws Exception {
        when(chatbot.reply(USER, 42L, new ChatbotReplyRequest("oi", null)))
                .thenThrow(new NotFoundException("Conversa 42 não encontrada"));

        send("{\"text\":\"oi\"}")
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("NOT_FOUND"));
    }

    @Test
    void reportsAFinishedConversationAsConflict() throws Exception {
        when(chatbot.reply(USER, 42L, new ChatbotReplyRequest("oi", null)))
                .thenThrow(new ConflictException("Conversa 42 não aceita mensagens no estado ENCAMINHAMENTO"));

        send("{\"text\":\"oi\"}")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("CONFLICT"));
    }

    @Test
    void rejectsAMissingBody() throws Exception {
        mockMvc.perform(post("/chatbot/conversations/42/messages").contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("BAD_REQUEST"));

        verifyNoInteractions(chatbot);
    }
}
