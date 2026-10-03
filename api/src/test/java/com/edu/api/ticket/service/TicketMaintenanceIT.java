package com.edu.api.ticket.service;

import com.edu.api.support.FullStackIntegration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;

class TicketMaintenanceIT extends FullStackIntegration {

    @Autowired
    private TicketMaintenanceService maintenance;

    private static OffsetDateTime now() {
        return OffsetDateTime.now(ZoneOffset.UTC);
    }

    @Test
    void escalatesOverdueTickets() {
        long requester = fx.user("USER");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA")
                .slaStartedAt(now().minusHours(5)).slaDueAt(now().minusHours(1)).insert();

        assertThat(maintenance.escalateOverdue()).isEqualTo(1);

        assertThat(fx.state(ticket).status()).isEqualTo("ESCALADO");
    }

    @Test
    void routesUnassignedTickets() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "GESTAO_ENTREGAS");
        long ticket = fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_FILA").insert();

        assertThat(maintenance.routeUnassigned()).isEqualTo(1);

        assertThat(fx.state(ticket).assignedEmployeeId()).isEqualTo(agent);
    }

    @Test
    void leavesWaitingTicketsAloneWhileNobodyIsOnline() {
        long requester = fx.user("USER");
        fx.employee("OFFLINE", "GESTAO_ENTREGAS");
        long ticket = fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_FILA").insert();

        assertThat(maintenance.routeUnassigned()).isZero();

        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ?", ticket)).isZero();
    }

    @Test
    void leavesTheTicketAloneWhenOnlyItsRequesterIsOnline() {
        long opener = fx.employee("ONLINE", "GESTAO_ENTREGAS");
        long ticket = fx.ticketFor(fx.userOf(opener), "PROBLEMA_PEDIDO").status("EM_FILA").insert();

        assertThat(maintenance.routeUnassigned()).isZero();

        assertThat(fx.state(ticket).assignedEmployeeId()).isNull();
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ?", ticket)).isZero();
    }

    @Test
    void closesTicketsResolvedMoreThan72HoursAgo() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long stale = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").assignedTo(agent)
                .resolvedAt(now().minusHours(73)).insert();
        long recent = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").assignedTo(agent)
                .resolvedAt(now().minusHours(1)).insert();

        assertThat(maintenance.closeStaleResolved()).isEqualTo(1);
        flush();

        assertThat(fx.state(stale).status()).isEqualTo("FECHADO");
        assertThat(fx.state(recent).status()).isEqualTo("RESOLVIDO");
        assertThat(fx.count("SELECT COUNT(*) FROM notifications WHERE ticket_id = ? AND type = 'TICKET_FECHADO'"
                + " AND recipient_user_id = ?", stale, fx.userOf(agent))).isEqualTo(1);
    }
}
