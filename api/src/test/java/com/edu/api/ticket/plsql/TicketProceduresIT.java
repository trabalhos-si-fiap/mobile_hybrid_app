package com.edu.api.ticket.plsql;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.support.TicketFixtures;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import static com.edu.api.support.TicketFixtures.T0;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Import(TicketProcedures.class)
class TicketProceduresIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private TicketProcedures procedures;

    private TicketFixtures fx;
    private long requester;

    @BeforeEach
    void setUp() {
        fx = new TicketFixtures(jdbc);
        requester = fx.user("USER");
    }

    @Test
    void routeReturnsTheChosenAgent() {
        long agent = fx.employee("ONLINE", "GESTAO_ENTREGAS");
        long ticket = fx.ticket(requester, "PROBLEMA_PEDIDO");

        assertThat(procedures.route(ticket)).contains(agent);
    }

    @Test
    void routeTranslatesAnUnknownTicket() {
        assertThatThrownBy(() -> procedures.route(-1))
                .isInstanceOf(NotFoundException.class)
                .hasMessage("Ticket -1 não encontrado");
    }

    @Test
    void routeTranslatesAnInvalidState() {
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("FECHADO").insert();

        assertThatThrownBy(() -> procedures.route(ticket)).isInstanceOf(ConflictException.class);
    }

    @Test
    void escalateOverdueReturnsHowManyWereEscalated() {
        fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").slaStartedAt(T0).slaDueAt(T0.plusMinutes(10)).insert();

        assertThat(procedures.escalateOverdue(T0.plusMinutes(11).toInstant())).isEqualTo(1);
    }

    @Test
    void slaStatusesAreReadForEveryTicket() {
        OffsetDateTime past = OffsetDateTime.now(ZoneOffset.UTC).minusDays(1);
        long breached = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO")
                .slaStartedAt(past.minusHours(1)).slaDueAt(past).insert();
        long met = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO")
                .slaStartedAt(past.minusHours(1)).slaDueAt(past).resolvedAt(past.minusMinutes(5)).insert();

        assertThat(procedures.slaStatuses(List.of(breached, met)))
                .containsEntry(breached, "ESTOURADO")
                .containsEntry(met, "CUMPRIDO");
    }
}
