package com.edu.api.support;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlParameterValue;
import org.springframework.jdbc.core.SqlTypeValue;
import org.springframework.jdbc.core.StatementCreatorUtils;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;

import java.sql.PreparedStatement;
import java.sql.Types;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

/**
 * Cria, via JDBC, os dados que cada teste precisa. Roda na transação do teste
 * e some no rollback; nunca depende do seed de demonstração.
 */
public final class TicketFixtures {

    /** Instante fixo para testes que não dependem do relógio. */
    public static final OffsetDateTime T0 = OffsetDateTime.parse("2030-01-01T12:00:00Z");

    public record TicketState(String status, String priority, Long assignedEmployeeId) {}

    private final JdbcTemplate jdbc;

    public TicketFixtures(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public long user(String role) {
        return insert("INSERT INTO admin_users (name, email, password, role) VALUES (?, ?, ?, ?)",
                "Pessoa " + role, role.toLowerCase() + "-" + UUID.randomUUID() + "@teste.edu", "x", role);
    }

    public long employee(String presence, String... skillCodes) {
        long employeeId = insert("INSERT INTO employees (user_id, presence) VALUES (?, ?)", user("EMPLOYEE"), presence);
        for (String code : skillCodes) {
            jdbc.update("INSERT INTO employee_skills (employee_id, skill_id) SELECT ?, id FROM skills WHERE code = ?",
                    employeeId, code);
        }
        return employeeId;
    }

    public long userOf(long employeeId) {
        return jdbc.queryForObject("SELECT user_id FROM employees WHERE id = ?", Long.class, employeeId);
    }

    public void lastAssignedAt(long employeeId, OffsetDateTime at) {
        jdbc.update("UPDATE employees SET last_assigned_at = ? WHERE id = ?", at, employeeId);
    }

    public long skillId(String code) {
        return jdbc.queryForObject("SELECT id FROM skills WHERE code = ?", Long.class, code);
    }

    public long ticket(long userId, String segment) {
        return ticketFor(userId, segment).insert();
    }

    public TicketRow ticketFor(long userId, String segment) {
        return new TicketRow(userId, segment);
    }

    public TicketState state(long ticketId) {
        Map<String, Object> row = jdbc.queryForMap(
                "SELECT status, priority, assigned_employee_id FROM tickets WHERE id = ?", ticketId);
        Number assigned = (Number) row.get("ASSIGNED_EMPLOYEE_ID");
        return new TicketState((String) row.get("STATUS"), (String) row.get("PRIORITY"),
                assigned == null ? null : assigned.longValue());
    }

    public int count(String sql, Object... args) {
        return jdbc.queryForObject(sql, Integer.class, args);
    }

    long insert(String sql, Object... args) {
        KeyHolder keys = new GeneratedKeyHolder();
        jdbc.update(con -> {
            PreparedStatement statement = con.prepareStatement(sql, new String[] {"ID"});
            for (int i = 0; i < args.length; i++) {
                StatementCreatorUtils.setParameterValue(statement, i + 1, SqlTypeValue.TYPE_UNKNOWN, args[i]);
            }
            return statement;
        }, keys);
        return keys.getKey().longValue();
    }

    private static Object number(Long value) {
        return value == null ? new SqlParameterValue(Types.NUMERIC, null) : value;
    }

    private static Object timestamp(OffsetDateTime value) {
        return value == null ? new SqlParameterValue(Types.TIMESTAMP, null) : value;
    }

    /** Linha de ticket com valores padrão; ajuste só o que o teste precisa. */
    public final class TicketRow {

        private final long userId;
        private final String segment;
        private String status = "ABERTO";
        private String priority = "NORMAL";
        private Long assignedEmployeeId;
        private OffsetDateTime createdAt = T0;
        private OffsetDateTime slaStartedAt;
        private OffsetDateTime slaDueAt;
        private OffsetDateTime resolvedAt;

        private TicketRow(long userId, String segment) {
            this.userId = userId;
            this.segment = segment;
        }

        public TicketRow status(String value) { status = value; return this; }
        public TicketRow priority(String value) { priority = value; return this; }
        public TicketRow assignedTo(Long employeeId) { assignedEmployeeId = employeeId; return this; }
        public TicketRow createdAt(OffsetDateTime value) { createdAt = value; return this; }
        public TicketRow slaStartedAt(OffsetDateTime value) { slaStartedAt = value; return this; }
        public TicketRow slaDueAt(OffsetDateTime value) { slaDueAt = value; return this; }
        public TicketRow resolvedAt(OffsetDateTime value) { resolvedAt = value; return this; }

        public long insert() {
            return TicketFixtures.this.insert(
                    "INSERT INTO tickets (user_id, segment, description, status, priority, assigned_employee_id,"
                            + " created_at, updated_at, sla_started_at, sla_due_at, resolved_at)"
                            + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    userId, segment, "Descrição de teste", status, priority, number(assignedEmployeeId),
                    createdAt, createdAt, timestamp(slaStartedAt), timestamp(slaDueAt), timestamp(resolvedAt));
        }
    }
}
