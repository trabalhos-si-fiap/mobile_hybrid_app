package com.edu.api.ticket.controller;

import com.edu.api.chatbot.dto.ChatbotMessageResponse;
import com.edu.api.chatbot.dto.ChatbotTranscriptResponse;
import com.edu.api.chatbot.entity.ChatbotSender;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.support.ControllerSliceTest;
import com.edu.api.support.WithAuthenticatedUser;
import com.edu.api.ticket.dto.*;
import com.edu.api.ticket.entity.*;
import com.edu.api.ticket.service.TicketService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.util.List;

import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ControllerSliceTest(TicketController.class)
@WithAuthenticatedUser
class TicketControllerTest {

    private static final AuthenticatedUser USER = new AuthenticatedUser(1L, "usuario@edu.com", "USER");
    private static final Instant AT = Instant.parse("2030-01-01T12:00:00Z");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private TicketService tickets;

    private static TicketDetailResponse detail(TicketStatus status) {
        return new TicketDetailResponse(7L, Segment.DEFEITO_APP, "Defeito no App / Problemas com App",
                TicketQueue.TECNOLOGIA, status, TicketPriority.ALTA, TicketChannel.APP, "O app fecha",
                "NO_PRAZO", null, new UserSummary(1L, "Usuário", "usuario@edu.com"), null, false, null,
                List.of(), AT, AT, null, null, null);
    }

    @Test
    void opensATicketWithAttachments() throws Exception {
        when(tickets.open(eq(USER), eq(Segment.DEFEITO_APP), eq("O app fecha"), anyList(), isNull()))
                .thenReturn(detail(TicketStatus.EM_FILA));

        mockMvc.perform(multipart("/tickets")
                        .file(new MockMultipartFile("files", "print.png", "image/png", new byte[] {1}))
                        .param("segment", "DEFEITO_APP")
                        .param("description", "O app fecha"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(7))
                .andExpect(jsonPath("$.status").value("EM_FILA"));

        verify(tickets).open(eq(USER), eq(Segment.DEFEITO_APP), eq("O app fecha"), argThat(files -> files.size() == 1),
                isNull());
    }

    @Test
    void opensATicketFromAChatbotConversation() throws Exception {
        when(tickets.open(eq(USER), eq(Segment.PROBLEMA_PEDIDO), eq("Pedido incompleto"), isNull(), eq(42L)))
                .thenReturn(detail(TicketStatus.EM_FILA));

        mockMvc.perform(multipart("/tickets")
                        .param("segment", "PROBLEMA_PEDIDO")
                        .param("description", "Pedido incompleto")
                        .param("chatbotConversationId", "42"))
                .andExpect(status().isCreated());

        verify(tickets).open(eq(USER), eq(Segment.PROBLEMA_PEDIDO), eq("Pedido incompleto"), isNull(), eq(42L));
    }

    @Test
    void returnsTheChatbotTranscript() throws Exception {
        when(tickets.chatbotConversation(USER, 7L)).thenReturn(new ChatbotTranscriptResponse(42L, AT,
                List.of(new ChatbotMessageResponse(1L, ChatbotSender.BOT, "Olá, Usuário!", AT))));

        mockMvc.perform(get("/tickets/7/chatbot-conversation"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.conversationId").value(42))
                .andExpect(jsonPath("$.startedAt").value("2030-01-01T12:00:00Z"))
                .andExpect(jsonPath("$.messages[0].sender").value("BOT"))
                .andExpect(jsonPath("$.messages[0].body").value("Olá, Usuário!"));
    }

    @Test
    void listsTheRequesterTickets() throws Exception {
        when(tickets.mine(USER)).thenReturn(List.of(new TicketSummaryResponse(7L, Segment.DEFEITO_APP,
                "Defeito no App / Problemas com App", TicketStatus.EM_FILA, TicketPriority.ALTA, "NO_PRAZO",
                null, "Usuário", null, false, AT, AT)));

        mockMvc.perform(get("/tickets/mine"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(7))
                .andExpect(jsonPath("$[0].slaStatus").value("NO_PRAZO"));
    }

    @Test
    void hidesTicketsTheUserCannotSee() throws Exception {
        when(tickets.detail(USER, 7L)).thenThrow(new NotFoundException("Ticket 7 não encontrado"));

        mockMvc.perform(get("/tickets/7"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("NOT_FOUND"));
    }

    @Test
    void reportsInvalidTransitionsAsConflict() throws Exception {
        when(tickets.confirm(USER, 7L)).thenThrow(new ConflictException("Não é possível fechar o ticket 7"));

        mockMvc.perform(post("/tickets/7/confirm"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("CONFLICT"));
    }

    @Test
    void rejectsAnUnknownSegment() throws Exception {
        mockMvc.perform(multipart("/tickets").param("segment", "XYZ").param("description", "Teste"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("BAD_REQUEST"));

        verifyNoInteractions(tickets);
    }

    @Test
    void streamsAnAttachmentInline() throws Exception {
        byte[] bytes = {1, 2, 3};
        when(tickets.download(USER, 7L, 9L))
                .thenReturn(new AttachmentDownload("print.png", "image/png", 3, new ByteArrayInputStream(bytes)));

        mockMvc.perform(get("/tickets/7/attachments/9"))
                .andExpect(status().isOk())
                .andExpect(content().contentType("image/png"))
                .andExpect(content().bytes(bytes))
                .andExpect(header().string("Content-Disposition", containsString("inline")))
                .andExpect(header().string("Content-Disposition", containsString("print.png")));
    }

    @Test
    void postsAMessage() throws Exception {
        when(tickets.postMessage(eq(USER), eq(7L), eq("Versão 2.3.1"), isNull()))
                .thenReturn(new MessageResponse(3L, SenderType.USER, "Usuário", "Versão 2.3.1", List.of(), AT));

        mockMvc.perform(multipart("/tickets/7/messages").param("body", "Versão 2.3.1"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.senderType").value("USER"));
    }
}
