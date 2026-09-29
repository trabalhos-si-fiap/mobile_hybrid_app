package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Dados de referência da migration V3 (não é o seed de demonstração). */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class ReferenceDataIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void triageMatrixMapsEachSegmentToItsSkillQueueAndSla() {
        List<String> rows = jdbc.queryForList(
                "SELECT c.segment || '>' || s.code || '>' || c.queue || '>' || c.default_priority"
                        + " || '>' || c.sla_minutes || '>' || c.escalation_minutes"
                        + " FROM ticket_tipo_config c JOIN skills s ON s.id = c.skill_id"
                        + " WHERE c.active = TRUE ORDER BY c.segment",
                String.class);

        assertThat(rows).containsExactly(
                "DEFEITO_APP>DESENVOLVEDOR>TECNOLOGIA>ALTA>240>60",
                "FEEDBACK_SUGESTAO>PRODUTO_MELHORIAS>PRODUTO>NORMAL>2880>720",
                "PROBLEMA_PEDIDO>GESTAO_ENTREGAS>MARKETPLACE>NORMAL>480>120");
    }

    @Test
    void rejectsUnknownRoles() {
        assertThatThrownBy(() -> jdbc.update(
                "INSERT INTO admin_users (name, email, password, role) VALUES ('X', 'x-role@teste.edu', 'x', 'GUEST')"))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("CK_ADMIN_USERS_ROLE");
    }
}
