package com.edu.api.ticket.plsql;

import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.ResultSetExtractor;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Types;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.function.Supplier;

/**
 * Único ponto do Java que chama o PL/SQL de tickets. Usa a conexão da
 * transação corrente; quem chama faz flush antes e refresh depois.
 */
@Component
public class TicketProcedures {

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;

    public TicketProcedures(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
    }

    /** PR_ROTEAR_TICKET: o atendente escolhido, ou vazio se ninguém estava online. */
    public Optional<Long> route(long ticketId) {
        return Optional.ofNullable(translated(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PR_ROTEAR_TICKET(?, ?)}")) {
                call.setLong(1, ticketId);
                call.registerOutParameter(2, Types.NUMERIC);
                call.execute();
                long employeeId = call.getLong(2);
                return call.wasNull() ? null : employeeId;
            }
        })));
    }

    /** PR_ESCALAR_TICKET_CRITICO: quantos tickets foram escalados. */
    public int escalateOverdue(Instant reference) {
        return translated(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PR_ESCALAR_TICKET_CRITICO(?, ?)}")) {
                call.setObject(1, reference.atOffset(ZoneOffset.UTC));
                call.registerOutParameter(2, Types.NUMERIC);
                call.execute();
                return call.getInt(2);
            }
        }));
    }

    /** FN_STATUS_SLA_TICKET de cada ticket, numa consulta só. */
    public Map<Long, String> slaStatuses(Collection<Long> ticketIds) {
        if (ticketIds.isEmpty()) {
            return Map.of();
        }
        return translated(() -> named.query(
                "SELECT id, FN_STATUS_SLA_TICKET(id) AS sla_status FROM tickets WHERE id IN (:ids)",
                Map.of("ids", ticketIds),
                (ResultSetExtractor<Map<Long, String>>) rs -> {
                    Map<Long, String> statuses = new HashMap<>();
                    while (rs.next()) {
                        statuses.put(rs.getLong("id"), rs.getString("sla_status"));
                    }
                    return statuses;
                }));
    }

    private static <T> T translated(Supplier<T> call) {
        try {
            return call.get();
        } catch (DataAccessException exception) {
            throw OracleErrors.translate(exception);
        }
    }
}
