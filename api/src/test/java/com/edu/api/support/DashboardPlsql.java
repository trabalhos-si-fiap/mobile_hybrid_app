package com.edu.api.support;

import org.springframework.jdbc.core.ColumnMapRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapperResultSetExtractor;
import org.springframework.jdbc.core.SqlParameterValue;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

/**
 * Chama o PL/SQL do dashboard diretamente, sem o gateway Java, como o
 * {@link Plsql} faz com o de tickets. Os cursores voltam como mapas coluna →
 * valor (NUMBER vira BigDecimal), sem diferenciar maiúsculas nos nomes.
 */
public final class DashboardPlsql {

    /** As linhas dos três cursores da PR_RESUMO_DASHBOARD. */
    public record Summary(List<Map<String, Object>> kpis, List<Map<String, Object>> segments,
                          List<Map<String, Object>> anomalies) {

        public Map<String, Object> kpi(String metric) {
            return find(kpis, "metrica", metric);
        }

        public Map<String, Object> segment(String segment) {
            return find(segments, "segment", segment);
        }

        public Map<String, Object> anomaly(String segment) {
            return find(anomalies, "segment", segment);
        }

        private static Map<String, Object> find(List<Map<String, Object>> rows, String column, String value) {
            return rows.stream()
                    .filter(row -> value.equals(row.get(column)))
                    .findFirst()
                    .orElseThrow(() -> new AssertionError(column + " " + value + " ausente em " + rows));
        }
    }

    private final JdbcTemplate jdbc;

    public DashboardPlsql(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public static BigDecimal number(Map<String, Object> row, String column) {
        return (BigDecimal) row.get(column);
    }

    public BigDecimal variationRate(Number current, Number previous) {
        return jdbc.queryForObject("SELECT FN_CALC_TAXA_VARIACAO(?, ?) FROM dual", BigDecimal.class,
                new SqlParameterValue(Types.NUMERIC, current), new SqlParameterValue(Types.NUMERIC, previous));
    }

    public Summary summary(int days, OffsetDateTime reference) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PR_RESUMO_DASHBOARD(?, ?, ?, ?, ?)}")) {
                call.setInt(1, days);
                call.setObject(2, reference);
                call.registerOutParameter(3, Types.REF_CURSOR);
                call.registerOutParameter(4, Types.REF_CURSOR);
                call.registerOutParameter(5, Types.REF_CURSOR);
                call.execute();
                return new Summary(rows(call, 3), rows(call, 4), rows(call, 5));
            }
        });
    }

    private static List<Map<String, Object>> rows(CallableStatement call, int index) throws SQLException {
        try (ResultSet cursor = call.getObject(index, ResultSet.class)) {
            return new RowMapperResultSetExtractor<>(new ColumnMapRowMapper()).extractData(cursor);
        }
    }
}
