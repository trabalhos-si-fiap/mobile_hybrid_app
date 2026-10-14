package com.edu.api.ticket.controller;

import com.edu.api.security.AuthenticatedUser;
import com.edu.api.support.ControllerSliceTest;
import com.edu.api.support.WithAuthenticatedUser;
import com.edu.api.ticket.dto.QueueScope;
import com.edu.api.ticket.dto.TicketDetailResponse;
import com.edu.api.ticket.dto.TicketSearchCriteria;
import com.edu.api.ticket.dto.UserSummary;
import com.edu.api.ticket.entity.*;
import com.edu.api.ticket.service.TicketStaffService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ControllerSliceTest(TicketStaffController.class)
@WithAuthenticatedUser(id = 2, email = "dev@edu.com", role = "EMPLOYEE")
class TicketStaffControllerTest {

    private static final AuthenticatedUser AGENT = new AuthenticatedUser(2L, "dev@edu.com", "EMPLOYEE");
    private static final Instant AT = Instant.parse("2030-01-01T12:00:00Z");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private TicketStaffService staff;

    private static TicketDetailResponse inService() {
        return new TicketDetailResponse(7L, Segment.DEFEITO_APP, "Defeito no App / Problemas com App",
                TicketQueue.TECNOLOGIA, TicketStatus.EM_ATENDIMENTO, TicketPriority.ALTA, TicketChannel.APP,
                "O app fecha", "NO_PRAZO", null, new UserSummary(1L, "Usuário", "usuario@edu.com"), null,
                false, null, List.of(), AT, AT, AT, null, null);
    }

    @Test
    void queueDefaultsToTheAgentOwnTickets() throws Exception {
        when(staff.queue(AGENT, QueueScope.MINE, null)).thenReturn(List.of());

        mockMvc.perform(get("/tickets/queue")).andExpect(status().isOk());

        verify(staff).queue(AGENT, QueueScope.MINE, null);
    }

    @Test
    void rejectsAnUnknownScope() throws Exception {
        mockMvc.perform(get("/tickets/queue").param("scope", "everything"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("BAD_REQUEST"));

        verifyNoInteractions(staff);
    }

    @Test
    void assumeReturnsTheTicket() throws Exception {
        when(staff.assume(AGENT, 7L)).thenReturn(inService());

        mockMvc.perform(post("/tickets/7/assume"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EM_ATENDIMENTO"));
    }

    @Test
    void transferRequiresATargetSegment() throws Exception {
        mockMvc.perform(post("/tickets/7/transfer").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"));

        verifyNoInteractions(staff);
    }

    @Test
    void engineeringAlertPassesTheReason() throws Exception {
        when(staff.engineeringAlert(AGENT, 7L, "Crash no checkout")).thenReturn(inService());

        mockMvc.perform(post("/tickets/7/engineering-alert")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"Crash no checkout\"}"))
                .andExpect(status().isOk());

        verify(staff).engineeringAlert(AGENT, 7L, "Crash no checkout");
    }

    private static TicketSearchCriteria defaults(Instant from) {
        return new TicketSearchCriteria(null, null, null, null, from, null, null, null,
                TicketSearchCriteria.Sort.CREATED_AT, TicketSearchCriteria.Direction.DESC, 50);
    }

    @Test
    void searchUsesTheDefaultsWhenNoParameterIsGiven() throws Exception {
        when(staff.search(AGENT, defaults(null))).thenReturn(List.of());

        mockMvc.perform(get("/tickets/search")).andExpect(status().isOk());

        verify(staff).search(AGENT, defaults(null));
    }

    @Test
    void searchPassesEveryFilterToTheService() throws Exception {
        TicketSearchCriteria expected = new TicketSearchCriteria(TicketStatus.EM_FILA, Segment.DEFEITO_APP,
                TicketPriority.ALTA, 9L, Instant.parse("2030-01-01T00:00:00Z"), Instant.parse("2030-01-02T00:00:00Z"),
                "tela branca", true, TicketSearchCriteria.Sort.PRIORITY, TicketSearchCriteria.Direction.ASC, 20);
        when(staff.search(AGENT, expected)).thenReturn(List.of());

        mockMvc.perform(get("/tickets/search")
                        .param("status", "EM_FILA").param("segment", "DEFEITO_APP").param("priority", "ALTA")
                        .param("assigneeId", "9")
                        .param("from", "2030-01-01T00:00:00Z").param("to", "2030-01-02T00:00:00Z")
                        .param("text", "  tela branca ").param("engineeringAlert", "true")
                        .param("sort", "priority").param("direction", "asc").param("limit", "20"))
                .andExpect(status().isOk());

        verify(staff).search(AGENT, expected);
    }

    @Test
    void searchAcceptsTimestampsWithAnOffset() throws Exception {
        TicketSearchCriteria expected = defaults(Instant.parse("2030-01-01T12:00:00Z"));
        when(staff.search(AGENT, expected)).thenReturn(List.of());

        mockMvc.perform(get("/tickets/search").param("from", "2030-01-01T09:00:00-03:00"))
                .andExpect(status().isOk());

        verify(staff).search(AGENT, expected);
    }

    @Test
    void searchRejectsAnUnknownSortBeforeTheService() throws Exception {
        mockMvc.perform(get("/tickets/search").param("sort", "name"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.message").value("sort: use createdAt, updatedAt, slaDueAt ou priority"));

        verifyNoInteractions(staff);
    }

    @Test
    void searchRejectsAnUnknownStatus() throws Exception {
        mockMvc.perform(get("/tickets/search").param("status", "PERDIDO"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("BAD_REQUEST"));

        verifyNoInteractions(staff);
    }
}
