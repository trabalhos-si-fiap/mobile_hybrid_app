package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.support.Plsql;
import com.edu.api.support.TicketFixtures;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import static com.edu.api.support.TicketFixtures.T0;
import static org.assertj.core.api.Assertions.assertThat;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class NextAgentFunctionIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    private TicketFixtures fx;
    private Plsql plsql;
    private long requester;
    private long devSkill;

    @BeforeEach
    void setUp() {
        fx = new TicketFixtures(jdbc);
        plsql = new Plsql(jdbc);
        requester = fx.user("USER");
        devSkill = fx.skillId("DESENVOLVEDOR");
    }

    @Test
    void picksTheOnlineAgentWithFewestActiveTickets() {
        long busy = fx.employee("ONLINE", "DESENVOLVEDOR");
        long free = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(busy).insert();

        assertThat(plsql.nextAgent(devSkill, null)).isEqualTo(free);
    }

    @Test
    void breaksTiesByTheLongestWithoutAssignment() {
        long recent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long waiting = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.lastAssignedAt(recent, T0);
        fx.lastAssignedAt(waiting, T0.minusHours(1));

        assertThat(plsql.nextAgent(devSkill, null)).isEqualTo(waiting);
    }

    @Test
    void ignoresOfflineAgentsAndOtherSkills() {
        fx.employee("OFFLINE", "DESENVOLVEDOR");
        fx.employee("AUSENTE", "DESENVOLVEDOR");
        fx.employee("ONLINE", "PRODUTO_MELHORIAS");

        assertThat(plsql.nextAgent(devSkill, null)).isNull();
    }

    @Test
    void skipsTheExcludedAgent() {
        long first = fx.employee("ONLINE", "DESENVOLVEDOR");
        long second = fx.employee("ONLINE", "DESENVOLVEDOR");

        assertThat(plsql.nextAgent(devSkill, first)).isEqualTo(second);
    }

    @Test
    void skipsTheAgentProfileOfTheRequester() {
        long opener = fx.employee("ONLINE", "DESENVOLVEDOR");
        long other = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.lastAssignedAt(other, T0);

        assertThat(plsql.nextAgent(devSkill, null, fx.userOf(opener))).isEqualTo(other);
        assertThat(plsql.nextAgent(devSkill, other, fx.userOf(opener))).isNull();
    }

    @Test
    void countsOnlyActiveTickets() {
        long withResolvedWork = fx.employee("ONLINE", "DESENVOLVEDOR");
        long other = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.lastAssignedAt(other, T0);
        fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").assignedTo(withResolvedWork).insert();

        assertThat(plsql.nextAgent(devSkill, null)).isEqualTo(withResolvedWork);
    }
}
