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

import java.time.OffsetDateTime;

import static com.edu.api.support.TicketFixtures.T0;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class SlaStatusFunctionIT extends OracleIntegrationTest {

    /** Janela de 100 minutos: 80% = 80 minutos. */
    private static final OffsetDateTime DUE = T0.plusMinutes(100);

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

    private long ticketInService() {
        return fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO")
                .slaStartedAt(T0).slaDueAt(DUE).insert();
    }

    @Test
    void isOnTimeBeforeEightyPercentOfTheWindow() {
        assertThat(plsql.slaStatus(ticketInService(), T0.plusMinutes(79))).isEqualTo("NO_PRAZO");
    }

    @Test
    void isAtRiskFromEightyPercentOfTheWindow() {
        assertThat(plsql.slaStatus(ticketInService(), T0.plusMinutes(80))).isEqualTo("EM_RISCO");
    }

    @Test
    void isBreachedAfterTheDueDate() {
        assertThat(plsql.slaStatus(ticketInService(), T0.plusMinutes(101))).isEqualTo("ESTOURADO");
    }

    @Test
    void isMetWhenResolvedBeforeTheDueDate() {
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO")
                .slaStartedAt(T0).slaDueAt(DUE).resolvedAt(T0.plusMinutes(50)).insert();

        assertThat(plsql.slaStatus(ticket, T0.plusMinutes(500))).isEqualTo("CUMPRIDO");
    }

    @Test
    void isViolatedWhenClosedAfterTheDueDate() {
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("FECHADO")
                .slaStartedAt(T0).slaDueAt(DUE).resolvedAt(T0.plusMinutes(120)).insert();

        assertThat(plsql.slaStatus(ticket, T0.plusMinutes(500))).isEqualTo("VIOLADO");
    }

    @Test
    void handlesWindowsLongerThanNinetyNineDays() {
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA")
                .slaStartedAt(T0).slaDueAt(T0.plusDays(200)).insert();

        assertThat(plsql.slaStatus(ticket, T0.plusDays(100))).isEqualTo("NO_PRAZO");
    }

    @Test
    void rejectsAnUnknownTicket() {
        assertThatThrownBy(() -> plsql.slaStatus(-1, T0)).hasMessageContaining("ORA-20001");
    }
}
