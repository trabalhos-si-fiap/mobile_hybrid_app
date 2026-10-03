package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.support.Plsql;
import com.edu.api.support.TicketFixtures;
import com.edu.api.support.TicketFixtures.TicketState;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.OffsetDateTime;

import static com.edu.api.support.TicketFixtures.T0;
import static org.assertj.core.api.Assertions.assertThat;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class EscalationProcedureIT extends OracleIntegrationTest {

    /** Um minuto depois do prazo dos tickets vencidos (T0 + 60). */
    private static final OffsetDateTime NOW = T0.plusMinutes(61);

    @Autowired
    private JdbcTemplate jdbc;

    private TicketFixtures fx;
    private Plsql plsql;
    private long requester;

    @BeforeEach
    void setUp() {
        fx = new TicketFixtures(jdbc);
        plsql = new Plsql(jdbc);
        requester = fx.user("USER");
    }

    private long overdueTicket(String status, String priority, Long owner) {
        return fx.ticketFor(requester, "DEFEITO_APP").status(status).priority(priority).assignedTo(owner)
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(60)).insert();
    }

    @Test
    void raisesPriorityAndHandsTheTicketToAnotherOnlineAgent() {
        long owner = fx.employee("ONLINE", "DESENVOLVEDOR");
        long other = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = overdueTicket("EM_ATENDIMENTO", "NORMAL", owner);

        assertThat(plsql.escalate(NOW)).isEqualTo(1);

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("ESCALADO", "ALTA", other));
        assertThat(fx.count("SELECT COUNT(*) FROM tickets WHERE id = ? AND sla_started_at = ? AND sla_due_at = ?",
                ticket, NOW, NOW.plusMinutes(60))).isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'ESCALADO'"
                + " AND employee_id = ? AND detail = 'Prioridade NORMAL -> ALTA'", ticket, other)).isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM notifications WHERE ticket_id = ? AND type = 'TICKET_ESCALADO'"
                + " AND recipient_user_id = ?", ticket, fx.userOf(other))).isEqualTo(1);
    }

    @Test
    void keepsTheOwnerWhenNoOtherAgentIsOnline() {
        long owner = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = overdueTicket("EM_FILA", "ALTA", owner);

        assertThat(plsql.escalate(NOW)).isEqualTo(1);

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("ESCALADO", "CRITICA", owner));
    }

    @Test
    void neverHandsTheTicketToTheAgentWhoOpenedIt() {
        long owner = fx.employee("ONLINE", "DESENVOLVEDOR");
        long opener = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(fx.userOf(opener), "DEFEITO_APP").status("EM_ATENDIMENTO").priority("NORMAL")
                .assignedTo(owner).slaStartedAt(T0).slaDueAt(T0.plusMinutes(60)).insert();

        assertThat(plsql.escalate(NOW)).isEqualTo(1);

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("ESCALADO", "ALTA", owner));
    }

    @Test
    void neverGoesAboveCritical() {
        long ticket = overdueTicket("ESCALADO", "CRITICA", null);

        assertThat(plsql.escalate(NOW)).isEqualTo(1);

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("ESCALADO", "CRITICA", null));
    }

    @Test
    void ignoresTicketsWithinTheirSlaOrAlreadyResolved() {
        long owner = fx.employee("ONLINE", "DESENVOLVEDOR");
        long onTime = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(owner)
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(120)).insert();
        long resolved = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").assignedTo(owner)
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(30)).resolvedAt(T0.plusMinutes(20)).insert();

        assertThat(plsql.escalate(NOW)).isZero();

        assertThat(fx.state(onTime).status()).isEqualTo("EM_ATENDIMENTO");
        assertThat(fx.state(resolved).status()).isEqualTo("RESOLVIDO");
    }
}
