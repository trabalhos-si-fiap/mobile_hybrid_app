package com.edu.api.dashboard.plsql;

import com.edu.api.dashboard.plsql.DashboardSummaryRows.AnomalyLine;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.Kpi;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.SegmentLine;
import com.edu.api.ticket.entity.Segment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

/**
 * Único ponto do Java que chama a PR_RESUMO_DASHBOARD. Só lê; um erro do
 * Oracle (como o ORA-20004 de período inválido) segue adiante, porque a API
 * valida o período antes de chegar aqui.
 */
@Component
public class DashboardProcedures {

    private final JdbcTemplate jdbc;

    public DashboardProcedures(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public DashboardSummaryRows summary(int days, Instant reference) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PR_RESUMO_DASHBOARD(?, ?, ?, ?, ?)}")) {
                call.setInt(1, days);
                call.setObject(2, reference.atOffset(ZoneOffset.UTC));
                call.registerOutParameter(3, Types.REF_CURSOR);
                call.registerOutParameter(4, Types.REF_CURSOR);
                call.registerOutParameter(5, Types.REF_CURSOR);
                call.execute();
                return new DashboardSummaryRows(
                        read(call, 3, DashboardProcedures::kpi),
                        read(call, 4, DashboardProcedures::segment),
                        read(call, 5, DashboardProcedures::anomaly));
            }
        });
    }

    private static <T> List<T> read(CallableStatement call, int index, RowMapper<T> mapper) throws SQLException {
        try (ResultSet cursor = call.getObject(index, ResultSet.class)) {
            List<T> rows = new ArrayList<>();
            while (cursor.next()) {
                rows.add(mapper.mapRow(cursor, rows.size()));
            }
            return rows;
        }
    }

    private static Kpi kpi(ResultSet rs, int row) throws SQLException {
        return new Kpi(rs.getString("metrica"), rs.getBigDecimal("atual"), rs.getBigDecimal("anterior"),
                rs.getBigDecimal("variacao"));
    }

    private static SegmentLine segment(ResultSet rs, int row) throws SQLException {
        return new SegmentLine(Segment.valueOf(rs.getString("segment")), rs.getString("label"),
                rs.getBigDecimal("abertos"), rs.getBigDecimal("abertos_anterior"), rs.getBigDecimal("abertos_variacao"),
                rs.getBigDecimal("resolvidos"), rs.getBigDecimal("resolvidos_anterior"),
                rs.getBigDecimal("resolvidos_variacao"),
                rs.getBigDecimal("sla_pct"), rs.getBigDecimal("sla_pct_anterior"), rs.getBigDecimal("sla_pct_variacao"),
                rs.getLong("backlog"));
    }

    private static AnomalyLine anomaly(ResultSet rs, int row) throws SQLException {
        return new AnomalyLine(Segment.valueOf(rs.getString("segment")), rs.getString("label"), rs.getLong("atual"),
                rs.getBigDecimal("media"), rs.getBigDecimal("desvio"), rs.getBigDecimal("z_score"),
                rs.getString("situacao"), rs.getInt("janelas"));
    }
}
