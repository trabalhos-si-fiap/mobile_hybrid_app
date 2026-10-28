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

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** TRG_TICKETS_AUDITORIA e TRG_TICKET_AUDITORIA_IMUTAVEL, só com os tickets de cada teste. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class TicketAuditTriggerIT extends OracleIntegrationTest {

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

    /** "CAMPO antes -> depois", com "-" no lugar de nulo, na ordem em que foi gravado. */
    private List<String> audit(long ticketId, String operation) {
        return jdbc.queryForList("SELECT campo || ' ' || NVL(valor_anterior, '-') || ' -> ' || NVL(valor_novo, '-')"
                + " FROM ticket_auditoria WHERE ticket_id = ? AND operacao = ? ORDER BY id",
                String.class, ticketId, operation);
    }

    @Test
    void anInsertRecordsTheInitialStateWithoutTheMissingOwner() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        assertThat(audit(ticket, "INSERT")).containsExactly(
                "STATUS - -> ABERTO", "PRIORITY - -> NORMAL", "SEGMENT - -> DEFEITO_APP", "ENGINEERING_ALERT - -> FALSE");
    }

    @Test
    void anUpdateRecordsOnlyTheChangedFieldsWithBeforeAndAfter() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET status = 'EM_FILA', priority = 'NORMAL', segment = 'PROBLEMA_PEDIDO'"
                + " WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE"))
                .containsExactly("STATUS ABERTO -> EM_FILA", "SEGMENT DEFEITO_APP -> PROBLEMA_PEDIDO");
    }

    @Test
    void anUpdateWithTheSameValuesRecordsNothing() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET status = status, priority = priority, assigned_employee_id = assigned_employee_id,"
                + " segment = segment, engineering_alert = engineering_alert WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE")).isEmpty();
    }

    @Test
    void anUpdateOfOtherColumnsRecordsNothing() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET description = 'Outra descrição', updated_at = SYSTIMESTAMP WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE")).isEmpty();
    }

    @Test
    void recordsTheOwnerBeingSetAndCleared() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET assigned_employee_id = ? WHERE id = ?", agent, ticket);
        jdbc.update("UPDATE tickets SET assigned_employee_id = NULL WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE"))
                .containsExactly("ASSIGNED_EMPLOYEE_ID - -> " + agent, "ASSIGNED_EMPLOYEE_ID " + agent + " -> -");
    }

    @Test
    void recordsTheEngineeringAlertBeingRaised() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET engineering_alert = TRUE WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE")).containsExactly("ENGINEERING_ALERT FALSE -> TRUE");
    }

    @Test
    void aDeleteRecordsTheFinalState() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("DELETE FROM tickets WHERE id = ?", ticket);

        assertThat(audit(ticket, "DELETE")).containsExactly(
                "STATUS ABERTO -> -", "PRIORITY NORMAL -> -", "SEGMENT DEFEITO_APP -> -", "ENGINEERING_ALERT FALSE -> -");
    }

    @Test
    void recordsTheDatabaseUserAndTheModule() {
        jdbc.execute("BEGIN DBMS_APPLICATION_INFO.SET_MODULE('teste-auditoria', NULL); END;");
        try {
            long ticket = fx.ticket(requester, "DEFEITO_APP");

            Map<String, Object> row = jdbc.queryForMap("SELECT usuario_banco, modulo FROM ticket_auditoria"
                    + " WHERE ticket_id = ? ORDER BY id FETCH FIRST 1 ROW ONLY", ticket);

            assertThat(row).containsEntry("usuario_banco", "EDU_ADMIN").containsEntry("modulo", "teste-auditoria");
        } finally {
            jdbc.execute("BEGIN DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL); END;");
        }
    }

    @Test
    void staysInTheCallerTransaction() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.execute("SAVEPOINT antes_da_mudanca");
        jdbc.update("UPDATE tickets SET status = 'EM_FILA' WHERE id = ?", ticket);
        jdbc.execute("ROLLBACK TO SAVEPOINT antes_da_mudanca");

        assertThat(audit(ticket, "UPDATE")).isEmpty();
        assertThat(audit(ticket, "INSERT")).isNotEmpty();
    }

    @Test
    void routingThroughTheProcedureIsAudited() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        plsql.route(ticket);

        assertThat(audit(ticket, "UPDATE")).containsExactly(
                "STATUS ABERTO -> EM_FILA", "PRIORITY NORMAL -> ALTA", "ASSIGNED_EMPLOYEE_ID - -> " + agent);
    }

    @Test
    void theAuditCannotBeChangedNorDeleted() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        assertThatThrownBy(() -> jdbc.update("UPDATE ticket_auditoria SET valor_novo = 'X' WHERE ticket_id = ?", ticket))
                .hasMessageContaining("ORA-20006");
        assertThatThrownBy(() -> jdbc.update("DELETE FROM ticket_auditoria WHERE ticket_id = ?", ticket))
                .hasMessageContaining("ORA-20006");
        assertThat(audit(ticket, "INSERT")).hasSize(4);
    }
}
