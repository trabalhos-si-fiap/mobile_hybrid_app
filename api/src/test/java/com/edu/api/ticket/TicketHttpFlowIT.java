package com.edu.api.ticket;

import com.edu.api.support.FullStackIntegration;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import static org.hamcrest.Matchers.contains;
import static org.springframework.http.HttpHeaders.AUTHORIZATION;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Do formulário do app ao fechamento confirmado, via HTTP e com JWT reais. */
class TicketHttpFlowIT extends FullStackIntegration {

    @Test
    void ticketGoesFromOpeningToConfirmedClosure() throws Exception {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        String userToken = bearer(requester, "USER");
        String agentToken = bearer(fx.userOf(agent), "EMPLOYEE");
        byte[] png = {(byte) 0x89, 'P', 'N', 'G', 1, 2, 3};

        String opened = mockMvc.perform(multipart("/tickets")
                        .file(new MockMultipartFile("files", "print.png", "image/png", png))
                        .param("segment", "DEFEITO_APP")
                        .param("description", "O app fecha ao abrir o carrinho")
                        .header(AUTHORIZATION, userToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("EM_FILA"))
                .andExpect(jsonPath("$.assignee.id").value(agent))
                .andExpect(jsonPath("$.attachments[0].fileName").value("print.png"))
                .andReturn().getResponse().getContentAsString();
        long ticketId = ((Number) JsonPath.read(opened, "$.id")).longValue();
        String downloadPath = JsonPath.read(opened, "$.attachments[0].downloadPath");

        mockMvc.perform(get("/notifications").param("unreadOnly", "true").header(AUTHORIZATION, agentToken))
                .andExpect(jsonPath("$[0].type").value("TICKET_ATRIBUIDO"));

        mockMvc.perform(post("/tickets/{id}/assume", ticketId).header(AUTHORIZATION, agentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EM_ATENDIMENTO"));

        mockMvc.perform(get("/notifications").header(AUTHORIZATION, userToken))
                .andExpect(jsonPath("$[0].type").value("TICKET_ASSUMIDO"));

        mockMvc.perform(multipart("/tickets/{id}/messages", ticketId)
                        .param("body", "Pode mandar a versão do app?")
                        .header(AUTHORIZATION, agentToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.senderType").value("EMPLOYEE"));

        mockMvc.perform(multipart("/tickets/{id}/messages", ticketId)
                        .param("body", "Versão 2.3.1")
                        .header(AUTHORIZATION, userToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.senderType").value("USER"));

        mockMvc.perform(get("/tickets/{id}/messages", ticketId).header(AUTHORIZATION, userToken))
                .andExpect(jsonPath("$.length()").value(2));

        mockMvc.perform(post("/tickets/{id}/resolve", ticketId).header(AUTHORIZATION, agentToken))
                .andExpect(jsonPath("$.status").value("RESOLVIDO"));

        mockMvc.perform(post("/tickets/{id}/confirm", ticketId).header(AUTHORIZATION, userToken))
                .andExpect(jsonPath("$.status").value("FECHADO"))
                .andExpect(jsonPath("$.slaStatus").value("CUMPRIDO"));

        mockMvc.perform(get("/tickets/{id}/events", ticketId).header(AUTHORIZATION, agentToken))
                .andExpect(jsonPath("$[*].type", contains("ABERTO", "ROTEADO", "ASSUMIDO", "RESOLVIDO", "FECHADO")));

        mockMvc.perform(get(downloadPath).header(AUTHORIZATION, userToken))
                .andExpect(status().isOk())
                .andExpect(content().contentType("image/png"))
                .andExpect(content().bytes(png));
    }
}
