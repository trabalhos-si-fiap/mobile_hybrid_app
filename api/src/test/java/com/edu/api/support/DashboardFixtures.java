package com.edu.api.support;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlParameterValue;

import java.sql.Types;
import java.time.OffsetDateTime;

/**
 * Tickets e eventos para os testes do dashboard, com datas em 2001: nenhum
 * outro teste cria dados antes disso (o {@link TicketFixtures#T0} é 2030),
 * então as contas da PR_RESUMO_DASHBOARD só enxergam os dados do teste.
 */
public final class DashboardFixtures {

    /** Referência dos testes do dashboard. */
    public static final OffsetDateTime REF = OffsetDateTime.parse("2001-03-01T12:00:00Z");

    private final JdbcTemplate jdbc;
    private final TicketFixtures rows;
    private final long requester;

    public DashboardFixtures(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.rows = new TicketFixtures(jdbc);
        this.requester = rows.user("USER");
    }

    public Ticket ticket(String segment, OffsetDateTime createdAt) {
        return new Ticket(segment, createdAt);
    }

    /** {@code count} tickets EM_FILA do segmento, todos abertos no mesmo instante. */
    public void opened(String segment, OffsetDateTime at, int count) {
        for (int i = 0; i < count; i++) {
            ticket(segment, at).insert();
        }
    }

    public void event(long ticketId, String type, OffsetDateTime at) {
        jdbc.update("INSERT INTO ticket_events (ticket_id, type, created_at) VALUES (?, ?, ?)", ticketId, type, at);
    }

    private static Object timestamp(OffsetDateTime value) {
        return value == null ? new SqlParameterValue(Types.TIMESTAMP, null) : value;
    }

    /** Ticket EM_FILA pelo app, sem SLA nem datas de atendimento; ajuste só o que o teste precisa. */
    public final class Ticket {

        private final String segment;
        private final OffsetDateTime createdAt;
        private String status = "EM_FILA";
        private String channel = "APP";
        private OffsetDateTime assumedAt;
        private OffsetDateTime resolvedAt;
        private OffsetDateTime slaDueAt;

        private Ticket(String segment, OffsetDateTime createdAt) {
            this.segment = segment;
            this.createdAt = createdAt;
        }

        public Ticket status(String value) { status = value; return this; }
        public Ticket channel(String value) { channel = value; return this; }
        public Ticket assumedAt(OffsetDateTime value) { assumedAt = value; return this; }
        public Ticket resolvedAt(OffsetDateTime value) { resolvedAt = value; return this; }
        public Ticket slaDueAt(OffsetDateTime value) { slaDueAt = value; return this; }

        public long insert() {
            return rows.insert(
                    "INSERT INTO tickets (user_id, segment, description, channel, status, created_at, updated_at,"
                            + " sla_started_at, sla_due_at, assumed_at, resolved_at)"
                            + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    requester, segment, "Ticket do dashboard", channel, status, createdAt, createdAt,
                    timestamp(slaDueAt == null ? null : createdAt), timestamp(slaDueAt),
                    timestamp(assumedAt), timestamp(resolvedAt));
        }
    }
}
