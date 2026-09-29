package com.edu.api.ticket.service;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.ForbiddenException;
import com.edu.api.support.FullStackIntegration;
import com.edu.api.ticket.dto.QueueScope;
import com.edu.api.ticket.dto.TicketDetailResponse;
import com.edu.api.ticket.dto.TicketSummaryResponse;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static com.edu.api.support.TicketFixtures.T0;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TicketStaffServiceIT extends FullStackIntegration {

    @Autowired
    private TicketStaffService staff;

    @Test
    void assumingStartsTheService() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").assignedTo(agent).insert();

        TicketDetailResponse assumed = staff.assume(login(fx.userOf(agent), "EMPLOYEE"), ticket);

        assertThat(assumed.status()).isEqualTo(TicketStatus.EM_ATENDIMENTO);
        assertThat(assumed.assumedAt()).isNotNull();
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'ASSUMIDO'"
                + " AND employee_id = ?", ticket, agent)).isEqualTo(1);
    }

    @Test
    void cannotAssumeATicketAlreadyInService() {
        long requester = fx.user("USER");
        long first = fx.employee("ONLINE", "DESENVOLVEDOR");
        long second = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(first).insert();

        assertThatThrownBy(() -> staff.assume(login(fx.userOf(second), "EMPLOYEE"), ticket))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void resolvingMovesTheTicketToResolved() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(agent).insert();

        TicketDetailResponse resolved = staff.resolve(login(fx.userOf(agent), "EMPLOYEE"), ticket);

        assertThat(resolved.status()).isEqualTo(TicketStatus.RESOLVIDO);
        assertThat(resolved.resolvedAt()).isNotNull();
    }

    @Test
    void transferReroutesToTheNewSkill() {
        long requester = fx.user("USER");
        long dev = fx.employee("ONLINE", "DESENVOLVEDOR");
        long product = fx.employee("ONLINE", "PRODUTO_MELHORIAS");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(dev).insert();

        TicketDetailResponse moved = staff.transfer(login(fx.userOf(dev), "EMPLOYEE"), ticket, Segment.FEEDBACK_SUGESTAO);

        assertThat(moved.segment()).isEqualTo(Segment.FEEDBACK_SUGESTAO);
        assertThat(moved.status()).isEqualTo(TicketStatus.EM_FILA);
        assertThat(moved.assignee().id()).isEqualTo(product);
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'TRANSFERIDO'"
                + " AND detail = 'DEFEITO_APP -> FEEDBACK_SUGESTAO'", ticket)).isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'ROTEADO'", ticket))
                .isEqualTo(1);
    }

    @Test
    void engineeringAlertFlagsTheTicket() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "GESTAO_ENTREGAS");
        long ticket = fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_ATENDIMENTO").assignedTo(agent).insert();

        TicketDetailResponse flagged = staff.engineeringAlert(login(fx.userOf(agent), "EMPLOYEE"), ticket,
                "Checkout duplicou a cobrança");

        assertThat(flagged.engineeringAlert()).isTrue();
        assertThat(flagged.engineeringAlertReason()).isEqualTo("Checkout duplicou a cobrança");
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'ALERTA_ENGENHARIA'",
                ticket)).isEqualTo(1);
    }

    @Test
    void myQueueIsOrderedByPriorityThenDeadline() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long normal = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").priority("NORMAL")
                .assignedTo(agent).slaStartedAt(T0).slaDueAt(T0.plusMinutes(10)).insert();
        long critical = fx.ticketFor(requester, "DEFEITO_APP").status("ESCALADO").priority("CRITICA")
                .assignedTo(agent).slaStartedAt(T0).slaDueAt(T0.plusMinutes(100)).insert();
        long high = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").priority("ALTA")
                .assignedTo(agent).slaStartedAt(T0).slaDueAt(T0.plusMinutes(5)).insert();

        assertThat(staff.queue(login(fx.userOf(agent), "EMPLOYEE"), QueueScope.MINE, null))
                .extracting(TicketSummaryResponse::id)
                .containsExactly(critical, high, normal);
    }

    @Test
    void skillsQueueShowsOnlyTheAgentSegments() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long defect = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_FILA").insert();

        assertThat(staff.queue(login(fx.userOf(agent), "EMPLOYEE"), QueueScope.SKILLS, null))
                .extracting(TicketSummaryResponse::id)
                .containsExactly(defect);
    }

    @Test
    void wholeQueueIsOnlyForAdmins() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");

        assertThatThrownBy(() -> staff.queue(login(fx.userOf(agent), "EMPLOYEE"), QueueScope.ALL, null))
                .isInstanceOf(ForbiddenException.class);
    }
}
