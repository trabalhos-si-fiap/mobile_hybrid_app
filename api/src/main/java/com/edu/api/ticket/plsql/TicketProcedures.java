package com.edu.api.ticket.plsql;

import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.shared.exception.UnprocessableException;
import com.edu.api.ticket.dto.TicketSearchCriteria;
import com.edu.api.ticket.dto.TicketSummaryResponse;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketPriority;
import com.edu.api.ticket.entity.TicketStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.ResultSetExtractor;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Supplier;

/**
 * Único ponto do Java que chama o PKG_TICKETS. Usa a conexão da
 * transação corrente; quem chama faz flush antes e refresh depois.
 */
@Component
public class TicketProcedures {

    private static final Logger log = LoggerFactory.getLogger(TicketProcedures.class);

    /** Tempo máximo da busca, em segundos. */
    private static final int SEARCH_TIMEOUT_SECONDS = 10;

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;

    public TicketProcedures(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
    }

    /** PKG_TICKETS.PR_ROTEAR_TICKET: o atendente escolhido, ou vazio se ninguém estava online. */
    public Optional<Long> route(long ticketId) {
        return Optional.ofNullable(translated(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PKG_TICKETS.PR_ROTEAR_TICKET(?, ?)}")) {
                call.setLong(1, ticketId);
                call.registerOutParameter(2, Types.NUMERIC);
                call.execute();
                long employeeId = call.getLong(2);
                return call.wasNull() ? null : employeeId;
            }
        })));
    }

    /**
     * Roteia os tickets um a um e devolve quantos ganharam atendente. Um ticket
     * que não pode ser roteado (sumiu, mudou de estado ou o segmento foi
     * desativado) fica de fora e o lote segue. Pegar a exceção aqui não estraga
     * a transação de quem chama: o Oracle desfaz só a chamada que falhou, e a
     * exceção não atravessa nenhum @Transactional.
     */
    public int routeEach(Collection<Long> ticketIds) {
        int assigned = 0;
        for (Long ticketId : ticketIds) {
            try {
                if (route(ticketId).isPresent()) {
                    assigned++;
                }
            } catch (NotFoundException | ConflictException | UnprocessableException e) {
                log.warn("Ticket {} não foi roteado: {}", ticketId, e.getMessage());
            }
        }
        return assigned;
    }

    /** PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO: quantos tickets foram escalados. */
    public int escalateOverdue(Instant reference) {
        return translated(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO(?, ?)}")) {
                call.setObject(1, reference.atOffset(ZoneOffset.UTC));
                call.registerOutParameter(2, Types.NUMERIC);
                call.execute();
                return call.getInt(2);
            }
        }));
    }

    /** PKG_TICKETS.FN_STATUS_SLA_TICKET de cada ticket, numa consulta só. */
    public Map<Long, String> slaStatuses(Collection<Long> ticketIds) {
        if (ticketIds.isEmpty()) {
            return Map.of();
        }
        return translated(() -> named.query(
                "SELECT id, PKG_TICKETS.FN_STATUS_SLA_TICKET(id) AS sla_status FROM tickets WHERE id IN (:ids)",
                Map.of("ids", ticketIds),
                (ResultSetExtractor<Map<Long, String>>) rs -> {
                    Map<Long, String> statuses = new HashMap<>();
                    while (rs.next()) {
                        statuses.put(rs.getLong("id"), rs.getString("sla_status"));
                    }
                    return statuses;
                }));
    }

    /**
     * PKG_TICKETS.PR_BUSCAR_TICKETS: a busca é montada por Dynamic SQL no banco,
     * que também aplica a visibilidade de quem busca (tudo, se seeAll).
     */
    public List<TicketSummaryResponse> search(TicketSearchCriteria criteria, long userId, boolean seeAll) {
        return translated(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall(
                    "{call PKG_TICKETS.PR_BUSCAR_TICKETS(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}")) {
                call.setQueryTimeout(SEARCH_TIMEOUT_SECONDS);
                call.setLong(1, userId);
                call.setBoolean(2, seeAll);
                bind(call, 3, criteria.status() == null ? null : criteria.status().name(), Types.VARCHAR);
                bind(call, 4, criteria.segment() == null ? null : criteria.segment().name(), Types.VARCHAR);
                bind(call, 5, criteria.priority() == null ? null : criteria.priority().name(), Types.VARCHAR);
                bind(call, 6, criteria.assigneeId(), Types.NUMERIC);
                bind(call, 7, utc(criteria.from()), Types.TIMESTAMP_WITH_TIMEZONE);
                bind(call, 8, utc(criteria.to()), Types.TIMESTAMP_WITH_TIMEZONE);
                bind(call, 9, criteria.text(), Types.VARCHAR);
                bind(call, 10, criteria.engineeringAlert(), Types.BOOLEAN);
                call.setString(11, criteria.sort().plsqlName());
                call.setString(12, criteria.direction().name());
                call.setInt(13, criteria.limit());
                call.setNull(14, Types.TIMESTAMP_WITH_TIMEZONE);
                call.registerOutParameter(15, Types.REF_CURSOR);
                call.execute();
                try (ResultSet cursor = call.getObject(15, ResultSet.class)) {
                    cursor.setFetchSize(criteria.limit());
                    List<TicketSummaryResponse> rows = new ArrayList<>();
                    while (cursor.next()) {
                        rows.add(summary(cursor));
                    }
                    return rows;
                }
            }
        }));
    }

    private static void bind(CallableStatement call, int index, Object value, int sqlType) throws SQLException {
        if (value == null) {
            call.setNull(index, sqlType);
        } else {
            call.setObject(index, value, sqlType);
        }
    }

    private static OffsetDateTime utc(Instant instant) {
        return instant == null ? null : instant.atOffset(ZoneOffset.UTC);
    }

    private static TicketSummaryResponse summary(ResultSet rs) throws SQLException {
        return new TicketSummaryResponse(rs.getLong("id"), Segment.valueOf(rs.getString("segment")),
                rs.getString("segment_label"), TicketStatus.valueOf(rs.getString("status")),
                TicketPriority.valueOf(rs.getString("priority")), rs.getString("sla_status"),
                instant(rs, "sla_due_at"), rs.getString("requester_name"), rs.getString("assignee_name"),
                rs.getBoolean("engineering_alert"), instant(rs, "created_at"), instant(rs, "updated_at"));
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        OffsetDateTime value = rs.getObject(column, OffsetDateTime.class);
        return value == null ? null : value.toInstant();
    }

    private static <T> T translated(Supplier<T> call) {
        try {
            return call.get();
        } catch (DataAccessException exception) {
            throw OracleErrors.translate(exception);
        }
    }
}
