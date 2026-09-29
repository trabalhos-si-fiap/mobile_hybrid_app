package com.edu.api.ticket.entity;

import com.edu.api.employee.entity.Employee;
import com.edu.api.shared.exception.ConflictException;
import com.edu.api.user.entity.AdminUser;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;

import static com.edu.api.support.Entities.employee;
import static com.edu.api.support.Entities.in;
import static com.edu.api.support.Entities.ticket;
import static com.edu.api.support.Entities.user;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TicketTest {

    private static final Instant NOW = Instant.parse("2030-01-01T12:00:00Z");

    private final AdminUser requester = user(1, "USER");
    private final Employee owner = employee(10, user(2, "EMPLOYEE"));
    private final Employee other = employee(11, user(3, "EMPLOYEE"));

    private Ticket queuedFor(Employee assignee) {
        return in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.EM_FILA, assignee);
    }

    @Test
    void opensAsNewWithNormalPriority() {
        Ticket opened = Ticket.open(requester, Segment.FEEDBACK_SUGESTAO, "Sugestão", TicketChannel.APP, NOW);

        assertThat(opened.getStatus()).isEqualTo(TicketStatus.ABERTO);
        assertThat(opened.getPriority()).isEqualTo(TicketPriority.NORMAL);
        assertThat(opened.getCreatedAt()).isEqualTo(NOW);
        assertThat(opened.isRequestedBy(1L)).isTrue();
    }

    @Test
    void ownerAssumesAQueuedTicket() {
        Ticket ticket = queuedFor(owner);

        ticket.assume(owner, false, NOW);

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.EM_ATENDIMENTO);
        assertThat(ticket.getAssumedAt()).isEqualTo(NOW);
        assertThat(ticket.getUpdatedAt()).isEqualTo(NOW);
    }

    @Test
    void anyAgentAssumesAnUnassignedTicket() {
        Ticket ticket = queuedFor(null);

        ticket.assume(other, false, NOW);

        assertThat(ticket.isAssignedTo(other)).isTrue();
    }

    @Test
    void cannotAssumeATicketAssignedToSomeoneElse() {
        Ticket ticket = queuedFor(owner);

        assertThatThrownBy(() -> ticket.assume(other, false, NOW)).isInstanceOf(ConflictException.class);
    }

    @Test
    void adminAssumesATicketAssignedToSomeoneElse() {
        Ticket ticket = queuedFor(owner);

        ticket.assume(other, true, NOW);

        assertThat(ticket.isAssignedTo(other)).isTrue();
    }

    @Test
    void cannotAssumeATicketAlreadyInService() {
        Ticket ticket = in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.EM_ATENDIMENTO, owner);

        assertThatThrownBy(() -> ticket.assume(owner, false, NOW)).isInstanceOf(ConflictException.class);
    }

    @Test
    void ownerResolvesATicketInService() {
        Ticket ticket = in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.EM_ATENDIMENTO, owner);

        ticket.resolve(owner, false, NOW);

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.RESOLVIDO);
        assertThat(ticket.getResolvedAt()).isEqualTo(NOW);
    }

    @Test
    void requesterConfirmsAResolvedTicket() {
        Ticket ticket = in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.RESOLVIDO, owner);

        ticket.confirm(NOW);

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.FECHADO);
        assertThat(ticket.getClosedAt()).isEqualTo(NOW);
    }

    @Test
    void reopeningRestartsTheSlaWindow() {
        Ticket ticket = in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.RESOLVIDO, owner);

        ticket.reopen(240, NOW);

        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.EM_ATENDIMENTO);
        assertThat(ticket.getResolvedAt()).isNull();
        assertThat(ticket.getSlaStartedAt()).isEqualTo(NOW);
        assertThat(ticket.getSlaDueAt()).isEqualTo(NOW.plus(Duration.ofMinutes(240)));
        assertThat(ticket.isAssignedTo(owner)).isTrue();
    }

    @Test
    void transferMovesTheTicketToTheNewQueueWithoutOwner() {
        Ticket ticket = in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.EM_ATENDIMENTO, owner);

        ticket.transferTo(Segment.FEEDBACK_SUGESTAO, owner, false, NOW);

        assertThat(ticket.getSegment()).isEqualTo(Segment.FEEDBACK_SUGESTAO);
        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.EM_FILA);
        assertThat(ticket.getAssignedEmployee()).isNull();
        assertThat(ticket.getSlaDueAt()).isNull();
        assertThat(ticket.getSlaStartedAt()).isNull();
    }

    @Test
    void cannotTransferToTheSameSegment() {
        Ticket ticket = in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.EM_ATENDIMENTO, owner);

        assertThatThrownBy(() -> ticket.transferTo(Segment.DEFEITO_APP, owner, false, NOW))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void engineeringAlertIsRejectedOnClosedTickets() {
        Ticket ticket = in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.FECHADO, owner);

        assertThatThrownBy(() -> ticket.raiseEngineeringAlert("Crash", owner, false, NOW))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void requesterCannotPostOnClosedTickets() {
        Ticket ticket = in(ticket(100, requester, Segment.DEFEITO_APP), TicketStatus.FECHADO, owner);

        assertThatThrownBy(ticket::requireUserCanPost).isInstanceOf(ConflictException.class);
    }

    @Test
    void agentPostsOnlyWhileInService() {
        Ticket queued = queuedFor(owner);
        Ticket inService = in(ticket(101, requester, Segment.DEFEITO_APP), TicketStatus.EM_ATENDIMENTO, owner);

        assertThatThrownBy(() -> queued.requireStaffCanPost(owner, false)).isInstanceOf(ConflictException.class);
        inService.requireStaffCanPost(owner, false);
    }

    @Test
    void returningToTheQueueDropsTheOwner() {
        Ticket ticket = queuedFor(owner);

        ticket.returnToQueue(NOW);

        assertThat(ticket.getAssignedEmployee()).isNull();
        assertThat(ticket.getStatus()).isEqualTo(TicketStatus.EM_FILA);
    }
}
