package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.Map;

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
    void everyPlsqlObjectIsAValidPackage() {
        List<String> invalid = jdbc.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects WHERE status = 'INVALID'", String.class);
        List<String> packages = jdbc.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects"
                        + " WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')", String.class);
        List<String> standalone = jdbc.queryForList(
                "SELECT object_name FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE')", String.class);

        assertThat(invalid).isEmpty();
        assertThat(packages).contains("PACKAGE PKG_TICKETS", "PACKAGE BODY PKG_TICKETS",
                "PACKAGE PKG_CHATBOT", "PACKAGE BODY PKG_CHATBOT",
                "PACKAGE PKG_DASHBOARD", "PACKAGE BODY PKG_DASHBOARD");
        assertThat(standalone).isEmpty();
    }

    @Test
    void packagesExposeOnlyTheirPublicMembers() {
        Map<String, List<String>> expected = Map.of(
                "PKG_TICKETS", List.of("FN_PROXIMO_ATENDENTE", "FN_STATUS_SLA_TICKET", "PR_ROTEAR_TICKET",
                        "PR_ESCALAR_TICKET_CRITICO"),
                "PKG_CHATBOT", List.of("FN_CHATBOT_RESPOSTA"),
                "PKG_DASHBOARD", List.of("FN_CALC_TAXA_VARIACAO", "PR_RESUMO_DASHBOARD"));

        expected.forEach((pkg, members) -> assertThat(jdbc.queryForList(
                "SELECT procedure_name FROM user_procedures WHERE object_name = ? AND procedure_name IS NOT NULL",
                String.class, pkg)).as(pkg).containsExactlyInAnyOrderElementsOf(members));
    }
}
