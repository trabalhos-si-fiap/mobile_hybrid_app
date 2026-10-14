package com.edu.api.support;

import org.springframework.jdbc.core.ColumnMapRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapperResultSetExtractor;
import org.springframework.jdbc.core.SqlParameterValue;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

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
        return jdbc.queryForObject("SELECT PKG_TICKETS.FN_STATUS_SLA_TICKET(?, ?) FROM dual", String.class,
                ticketId, reference);
    }

    public Long nextAgent(long skillId, Long excludedEmployeeId) {
        return jdbc.queryForObject("SELECT PKG_TICKETS.FN_PROXIMO_ATENDENTE(?, ?) FROM dual", Long.class,
                skillId, new SqlParameterValue(Types.NUMERIC, excludedEmployeeId));
    }

    public Long nextAgent(long skillId, Long excludedEmployeeId, Long requesterUserId) {
        return jdbc.queryForObject("SELECT PKG_TICKETS.FN_PROXIMO_ATENDENTE(?, ?, ?) FROM dual", Long.class,
                skillId, new SqlParameterValue(Types.NUMERIC, excludedEmployeeId),
                new SqlParameterValue(Types.NUMERIC, requesterUserId));
    }

    public Long route(long ticketId) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PKG_TICKETS.PR_ROTEAR_TICKET(?, ?)}")) {
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
            try (CallableStatement call = con.prepareCall("{call PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO(?, ?)}")) {
                call.setObject(1, reference);
                call.registerOutParameter(2, Types.NUMERIC);
                call.execute();
                return call.getInt(2);
            }
        });
    }

    /** Parâmetros da PKG_TICKETS.PR_BUSCAR_TICKETS; o que não for informado vai nulo. */
    public static final class TicketSearch {

        private final Long userId;
        private final Boolean seeAll;
        private String status;
        private String segment;
        private String priority;
        private Long assigneeId;
        private OffsetDateTime from;
        private OffsetDateTime to;
        private String text;
        private Boolean engineeringAlert;
        private String sort;
        private String direction;
        private Integer limit;
        private OffsetDateTime reference;

        public TicketSearch(Long userId, Boolean seeAll) {
            this.userId = userId;
            this.seeAll = seeAll;
        }

        /** Restrita ao que o usuário pode ver. */
        public static TicketSearch as(long userId) { return new TicketSearch(userId, false); }
        public static TicketSearch asAdmin(long userId) { return new TicketSearch(userId, true); }

        public TicketSearch status(String value) { status = value; return this; }
        public TicketSearch segment(String value) { segment = value; return this; }
        public TicketSearch priority(String value) { priority = value; return this; }
        public TicketSearch assignee(long employeeId) { assigneeId = employeeId; return this; }
        public TicketSearch createdBetween(OffsetDateTime start, OffsetDateTime end) {
            from = start;
            to = end;
            return this;
        }
        public TicketSearch text(String value) { text = value; return this; }
        public TicketSearch engineeringAlert(boolean value) { engineeringAlert = value; return this; }
        public TicketSearch sort(String column, String dir) { sort = column; direction = dir; return this; }
        public TicketSearch limit(int value) { limit = value; return this; }
        public TicketSearch reference(OffsetDateTime value) { reference = value; return this; }
    }

    /** As linhas do cursor como mapas coluna → valor, sem diferenciar maiúsculas nos nomes. */
    public List<Map<String, Object>> search(TicketSearch s) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall(
                    "{call PKG_TICKETS.PR_BUSCAR_TICKETS(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}")) {
                bind(call, 1, s.userId, Types.NUMERIC);
                bind(call, 2, s.seeAll, Types.BOOLEAN);
                bind(call, 3, s.status, Types.VARCHAR);
                bind(call, 4, s.segment, Types.VARCHAR);
                bind(call, 5, s.priority, Types.VARCHAR);
                bind(call, 6, s.assigneeId, Types.NUMERIC);
                bind(call, 7, s.from, Types.TIMESTAMP_WITH_TIMEZONE);
                bind(call, 8, s.to, Types.TIMESTAMP_WITH_TIMEZONE);
                bind(call, 9, s.text, Types.VARCHAR);
                bind(call, 10, s.engineeringAlert, Types.BOOLEAN);
                bind(call, 11, s.sort, Types.VARCHAR);
                bind(call, 12, s.direction, Types.VARCHAR);
                bind(call, 13, s.limit, Types.NUMERIC);
                bind(call, 14, s.reference, Types.TIMESTAMP_WITH_TIMEZONE);
                call.registerOutParameter(15, Types.REF_CURSOR);
                call.execute();
                try (ResultSet cursor = call.getObject(15, ResultSet.class)) {
                    return new RowMapperResultSetExtractor<>(new ColumnMapRowMapper()).extractData(cursor);
                }
            }
        });
    }

    private static void bind(CallableStatement call, int index, Object value, int sqlType) throws SQLException {
        if (value == null) {
            call.setNull(index, sqlType);
        } else {
            call.setObject(index, value, sqlType);
        }
    }
}
