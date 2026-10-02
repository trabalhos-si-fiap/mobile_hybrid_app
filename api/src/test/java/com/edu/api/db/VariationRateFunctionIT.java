package com.edu.api.db;

import com.edu.api.support.DashboardPlsql;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class VariationRateFunctionIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    private DashboardPlsql plsql;

    @BeforeEach
    void setUp() {
        plsql = new DashboardPlsql(jdbc);
    }

    @Test
    void risesAsAPositivePercentage() {
        assertThat(plsql.variationRate(31, 24)).isEqualByComparingTo("29.2");
    }

    @Test
    void fallsAsANegativePercentage() {
        assertThat(plsql.variationRate(2, 3)).isEqualByComparingTo("-33.3");
    }

    @Test
    void staysAtZeroWithoutChange() {
        assertThat(plsql.variationRate(5, 5)).isEqualByComparingTo("0");
    }

    @Test
    void isNullWithoutAPreviousValue() {
        assertThat(plsql.variationRate(5, 0)).isNull();
        assertThat(plsql.variationRate(5, null)).isNull();
    }

    @Test
    void isNullWithoutACurrentValue() {
        assertThat(plsql.variationRate(null, 5)).isNull();
    }

    @Test
    void roundsToOneDecimal() {
        assertThat(plsql.variationRate(1, 3)).isEqualByComparingTo("-66.7");
        assertThat(plsql.variationRate(new BigDecimal("88.9"), new BigDecimal("92"))).isEqualByComparingTo("-3.4");
    }
}
