package com.edu.api.ticket;

import com.edu.api.support.FullStackIntegration;
import org.junit.jupiter.api.Test;

import static org.springframework.http.HttpHeaders.AUTHORIZATION;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Regras de acesso dos tickets pela cadeia de segurança real. */
class TicketSecurityIT extends FullStackIntegration {

    @Test
    void aUserCannotOpenAnotherUsersTicket() throws Exception {
        long owner = fx.user("USER");
        long stranger = fx.user("USER");
        long ticket = fx.ticket(owner, "DEFEITO_APP");

        mockMvc.perform(get("/tickets/{id}", ticket).header(AUTHORIZATION, bearer(stranger, "USER")))
                .andExpect(status().isNotFound());
    }

    @Test
    void aUserIsForbiddenOnTheQueue() throws Exception {
        long user = fx.user("USER");

        mockMvc.perform(get("/tickets/queue").header(AUTHORIZATION, bearer(user, "USER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void theSkillsQueueShowsOnlyTheAgentSegments() throws Exception {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_FILA").insert();

        mockMvc.perform(get("/tickets/queue").param("scope", "skills")
                        .header(AUTHORIZATION, bearer(fx.userOf(agent), "EMPLOYEE")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].segment").value("DEFEITO_APP"));
    }

    @Test
    void agentsCannotSeeTheWholeQueue() throws Exception {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");

        mockMvc.perform(get("/tickets/queue").param("scope", "all")
                        .header(AUTHORIZATION, bearer(fx.userOf(agent), "EMPLOYEE")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    @Test
    void adminsSeeTheWholeQueue() throws Exception {
        long requester = fx.user("USER");
        long admin = fx.user("ADMIN");
        fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_FILA").insert();

        mockMvc.perform(get("/tickets/queue").param("scope", "all").header(AUTHORIZATION, bearer(admin, "ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));
    }
}
