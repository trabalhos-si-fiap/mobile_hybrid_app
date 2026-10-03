package com.edu.api.support;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlParameterValue;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Types;
import java.time.OffsetDateTime;

/**
 * Chama os objetos PL/SQL diretamente, sem o gateway Java, para que os testes
 * do banco não dependam do código de produção que os usa.
 */
public final class Plsql {

    private final JdbcTemplate jdbc;

    public Plsql(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public String slaStatus(long ticketId, OffsetDateTime reference) {
        return jdbc.queryForObject("SELECT FN_STATUS_SLA_TICKET(?, ?) FROM dual", String.class, ticketId, reference);
    }

    public Long nextAgent(long skillId, Long excludedEmployeeId) {
        return jdbc.queryForObject("SELECT FN_PROXIMO_ATENDENTE(?, ?) FROM dual", Long.class,
                skillId, new SqlParameterValue(Types.NUMERIC, excludedEmployeeId));
    }

    public Long nextAgent(long skillId, Long excludedEmployeeId, Long requesterUserId) {
        return jdbc.queryForObject("SELECT FN_PROXIMO_ATENDENTE(?, ?, ?) FROM dual", Long.class,
                skillId, new SqlParameterValue(Types.NUMERIC, excludedEmployeeId),
                new SqlParameterValue(Types.NUMERIC, requesterUserId));
    }

    public Long route(long ticketId) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PR_ROTEAR_TICKET(?, ?)}")) {
                call.setLong(1, ticketId);
                call.registerOutParameter(2, Types.NUMERIC);
                call.execute();
                long employeeId = call.getLong(2);
                return call.wasNull() ? null : employeeId;
            }
        });
    }

    public int escalate(OffsetDateTime reference) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PR_ESCALAR_TICKET_CRITICO(?, ?)}")) {
                call.setObject(1, reference);
                call.registerOutParameter(2, Types.NUMERIC);
                call.execute();
                return call.getInt(2);
            }
        });
    }
}
