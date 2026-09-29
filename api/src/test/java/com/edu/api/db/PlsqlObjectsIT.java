package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * O Oracle compila PL/SQL com erro como objeto INVALID em vez de falhar a
 * migration; este teste é o que pega isso.
 */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class PlsqlObjectsIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void everyPlsqlObjectExistsAndCompiles() {
        List<String> invalid = jdbc.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects WHERE status = 'INVALID'", String.class);
        List<String> objects = jdbc.queryForList(
                "SELECT object_name FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE')", String.class);

        assertThat(invalid).isEmpty();
        assertThat(objects).contains("FN_PROXIMO_ATENDENTE", "FN_STATUS_SLA_TICKET", "PR_ROTEAR_TICKET", "PR_ESCALAR_TICKET_CRITICO");
    }
}
