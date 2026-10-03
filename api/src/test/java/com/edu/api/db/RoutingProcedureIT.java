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

import static com.edu.api.support.TicketFixtures.T0;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class RoutingProcedureIT extends OracleIntegrationTest {

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

    @Test
    void assignsTheTicketToAnOnlineAgentOfTheSegmentSkill() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        assertThat(plsql.route(ticket)).isEqualTo(agent);

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("EM_FILA", "ALTA", agent));
        assertThat(fx.count("SELECT COUNT(*) FROM tickets WHERE id = ? AND sla_started_at IS NOT NULL"
                + " AND sla_due_at = sla_started_at + NUMTODSINTERVAL(240, 'MINUTE')", ticket)).isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'ROTEADO'"
                + " AND employee_id = ? AND from_status = 'ABERTO' AND to_status = 'EM_FILA'", ticket, agent)).isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM notifications WHERE ticket_id = ? AND type = 'TICKET_ATRIBUIDO'"
                + " AND recipient_user_id = ?", ticket, fx.userOf(agent))).isEqualTo(1);
    }

    @Test
    void queuesWithoutOwnerWhenNobodyIsOnline() {
        fx.employee("OFFLINE", "DESENVOLVEDOR");
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        assertThat(plsql.route(ticket)).isNull();

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("EM_FILA", "ALTA", null));
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ? AND type = 'ROTEADO'"
                + " AND detail LIKE '%nenhum atendente online%'", ticket)).isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM notifications WHERE ticket_id = ?", ticket)).isZero();
    }

    @Test
    void neverAssignsTheTicketToTheAgentWhoOpenedIt() {
        long opener = fx.employee("ONLINE", "DESENVOLVEDOR");
        long other = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.lastAssignedAt(other, T0);
        long ticket = fx.ticket(fx.userOf(opener), "DEFEITO_APP");

        assertThat(plsql.route(ticket)).isEqualTo(other);
    }

    @Test
    void queuesWithoutOwnerWhenOnlyTheAgentWhoOpenedItIsOnline() {
        long opener = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticket(fx.userOf(opener), "DEFEITO_APP");

        assertThat(plsql.route(ticket)).isNull();

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("EM_FILA", "ALTA", null));
    }

    @Test
    void keepsTheSlaWindowWhenRoutingAnEscalatedTicket() {
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("ESCALADO").priority("CRITICA")
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(60)).insert();
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");

        assertThat(plsql.route(ticket)).isEqualTo(agent);

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("ESCALADO", "CRITICA", agent));
        assertThat(fx.count("SELECT COUNT(*) FROM tickets WHERE id = ? AND sla_started_at = ? AND sla_due_at = ?",
                ticket, T0, T0.plusMinutes(60))).isEqualTo(1);
    }

    @Test
    void rejectsAnUnknownTicket() {
        assertThatThrownBy(() -> plsql.route(-1)).hasMessageContaining("ORA-20001");
    }

    @Test
    void rejectsATicketAlreadyInService() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(agent).insert();

        assertThatThrownBy(() -> plsql.route(ticket)).hasMessageContaining("ORA-20002");
    }

    @Test
    void rejectsASegmentWithoutActiveConfiguration() {
        jdbc.update("UPDATE ticket_tipo_config SET active = FALSE WHERE segment = 'FEEDBACK_SUGESTAO'");
        long ticket = fx.ticket(requester, "FEEDBACK_SUGESTAO");

        assertThatThrownBy(() -> plsql.route(ticket)).hasMessageContaining("ORA-20003");
    }
}
