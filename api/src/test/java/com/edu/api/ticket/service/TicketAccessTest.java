package com.edu.api.ticket.service;

import com.edu.api.employee.entity.Employee;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketStatus;
import com.edu.api.user.entity.AdminUser;
import org.junit.jupiter.api.Test;

import java.util.Set;

import static com.edu.api.support.Entities.employee;
import static com.edu.api.support.Entities.in;
import static com.edu.api.support.Entities.ticket;
import static com.edu.api.support.Entities.user;
import static org.assertj.core.api.Assertions.assertThat;

class TicketAccessTest {

    private final AdminUser requester = user(1, "USER");
    private final Employee agent = employee(10, user(2, "EMPLOYEE"));
    private final AuthenticatedUser agentLogin = new AuthenticatedUser(2L, "p2@teste.edu", "EMPLOYEE");
    private final Ticket ticket = ticket(100, requester, Segment.DEFEITO_APP);

    @Test
    void requesterSeesOwnTicket() {
        assertThat(TicketAccess.canView(new AuthenticatedUser(1L, "p1@teste.edu", "USER"), null, ticket, Set.of())).isTrue();
    }

    @Test
    void anotherUserDoesNotSeeTheTicket() {
        assertThat(TicketAccess.canView(new AuthenticatedUser(9L, "p9@teste.edu", "USER"), null, ticket, Set.of())).isFalse();
    }

    @Test
    void agentSeesTicketsAssignedToThem() {
        in(ticket, TicketStatus.EM_FILA, agent);

        assertThat(TicketAccess.canView(agentLogin, agent, ticket, Set.of())).isTrue();
    }

    @Test
    void agentSeesTicketsOfTheirSkillQueue() {
        assertThat(TicketAccess.canView(agentLogin, agent, ticket, Set.of(Segment.DEFEITO_APP))).isTrue();
    }

    @Test
    void agentDoesNotSeeOtherQueues() {
        assertThat(TicketAccess.canView(agentLogin, agent, ticket, Set.of(Segment.PROBLEMA_PEDIDO))).isFalse();
    }

    @Test
    void adminSeesEverything() {
        assertThat(TicketAccess.canView(new AuthenticatedUser(5L, "admin@edu.com", "ADMIN"), null, ticket, Set.of())).isTrue();
    }
}
