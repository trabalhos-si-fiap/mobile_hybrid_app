package com.edu.api.support;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlParameterValue;

import java.math.BigDecimal;
import java.sql.Types;

/**
 * Chama o PL/SQL do dashboard diretamente, sem o gateway Java, como o
 * {@link Plsql} faz com o de tickets.
 */
public final class DashboardPlsql {

    private final JdbcTemplate jdbc;

    public DashboardPlsql(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public BigDecimal variationRate(Number current, Number previous) {
        return jdbc.queryForObject("SELECT FN_CALC_TAXA_VARIACAO(?, ?) FROM dual", BigDecimal.class,
                new SqlParameterValue(Types.NUMERIC, current), new SqlParameterValue(Types.NUMERIC, previous));
    }
}
