package com.edu.api.ticket.plsql;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.shared.exception.UnprocessableException;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.UncategorizedSQLException;

import java.sql.SQLException;

import static org.assertj.core.api.Assertions.assertThat;

class OracleErrorsTest {

    private static UncategorizedSQLException oracle(int code, String message) {
        return new UncategorizedSQLException("call", "{call X}",
                new SQLException("ORA-" + code + ": " + message + "\nORA-06512: at \"EDU_ADMIN.X\", line 12", "72000", code));
    }

    @Test
    void unknownTicketBecomesNotFound() {
        RuntimeException translated = OracleErrors.translate(oracle(20001, "Ticket 7 não encontrado"));

        assertThat(translated).isInstanceOf(NotFoundException.class).hasMessage("Ticket 7 não encontrado");
    }

    @Test
    void invalidStateBecomesConflict() {
        assertThat(OracleErrors.translate(oracle(20002, "Ticket 7 não pode ser roteado")))
                .isInstanceOf(ConflictException.class)
                .hasMessage("Ticket 7 não pode ser roteado");
    }

    @Test
    void missingConfigurationBecomesUnprocessable() {
        assertThat(OracleErrors.translate(oracle(20003, "Segmento X sem configuração ativa")))
                .isInstanceOf(UnprocessableException.class);
    }

    @Test
    void otherErrorsAreKept() {
        UncategorizedSQLException original = oracle(1400, "cannot insert NULL");

        assertThat(OracleErrors.translate(original)).isSameAs(original);
    }
}
