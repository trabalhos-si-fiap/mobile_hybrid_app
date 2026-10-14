package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.flywaydb.core.api.MigrationState;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.context.ActiveProfiles;

import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * O caminho de quem já tinha o banco antes dos packages: um schema migrado com
 * os sete objetos standalone (os R__ antigos, copiados em db/plsql-legado)
 * migra de novo com as pastas e a configuração atuais do Flyway.
 */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class FlywayUpgradeIT extends OracleIntegrationTest {

    private static final String USER = "FLYWAY_LEGADO";
    private static final String PASSWORD = "Legado_123";
    private static final List<String> REMOVED = List.of("fn calc taxa variacao", "fn chatbot resposta",
            "fn proximo atendente", "fn status sla ticket", "pr escalar ticket critico", "pr resumo dashboard",
            "pr rotear ticket");

    @Autowired
    private Flyway configured;

    private final JdbcTemplate system = new JdbcTemplate(systemDataSource());
    private DriverManagerDataSource legacySchema;

    @BeforeEach
    void createLegacySchema() {
        dropUser();
        system.execute("CREATE USER " + USER + " IDENTIFIED BY \"" + PASSWORD + "\""
                + " DEFAULT TABLESPACE users QUOTA UNLIMITED ON users");
        system.execute("GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER TO " + USER);
        legacySchema = new DriverManagerDataSource(jdbcUrl(), USER, PASSWORD);

        Flyway.configure()
                .dataSource(legacySchema)
                .locations("classpath:db/migration", "classpath:db/plsql-legado")
                .target("10")
                .load()
                .migrate();
    }

    @AfterEach
    void dropLegacySchema() {
        dropUser();
    }

    /** O Oracle pode ainda não ter encerrado a sessão de uma conexão já fechada (ORA-01940 no DROP USER). */
    private void dropUser() {
        for (String session : system.queryForList(
                "SELECT sid || ',' || serial# FROM v$session WHERE username = ?", String.class, USER)) {
            system.execute("ALTER SYSTEM KILL SESSION '" + session + "' IMMEDIATE");
        }
        Integer users = system.queryForObject("SELECT COUNT(*) FROM dba_users WHERE username = ?", Integer.class, USER);
        if (users > 0) {
            system.execute("DROP USER " + USER + " CASCADE");
        }
    }

    /** A configuração da aplicação (pastas e padrões ignorados), apontada para o schema antigo. */
    private Flyway current() {
        return Flyway.configure().configuration(configured.getConfiguration()).dataSource(legacySchema).load();
    }

    @Test
    void upgradesASchemaThatHadTheStandaloneObjects() {
        current().migrate();

        JdbcTemplate schema = new JdbcTemplate(legacySchema);
        assertThat(schema.queryForList(
                "SELECT object_name FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE')", String.class))
                .isEmpty();
        assertThat(schema.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects WHERE status = 'INVALID'", String.class))
                .isEmpty();
        assertThat(schema.queryForList(
                "SELECT object_name FROM user_objects WHERE object_type = 'PACKAGE BODY'", String.class))
                .containsExactlyInAnyOrder("PKG_TICKETS", "PKG_CHATBOT", "PKG_DASHBOARD");
        assertThat(Arrays.stream(current().info().all())
                .filter(migration -> migration.getState() == MigrationState.MISSING_SUCCESS)
                .map(MigrationInfo::getDescription)
                .toList())
                .containsExactlyInAnyOrderElementsOf(REMOVED);
    }

    @Test
    void refusesToUpgradeWithoutToleratingTheRemovedRepeatables() {
        Flyway strict = Flyway.configure().configuration(configured.getConfiguration())
                .dataSource(legacySchema)
                .ignoreMigrationPatterns("*:future")
                .load();

        assertThatThrownBy(strict::migrate).hasMessageContaining("not resolved locally");
        assertThat(new JdbcTemplate(legacySchema).queryForList(
                "SELECT object_name FROM user_objects WHERE object_type = 'FUNCTION'", String.class))
                .contains("FN_STATUS_SLA_TICKET");
    }
}
