package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class DashboardIndexesIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void indexesTheColumnsTheDashboardAggregates() {
        List<String> indexes = jdbc.queryForList(
                "SELECT index_name FROM user_indexes WHERE table_name IN ('TICKETS', 'TICKET_EVENTS')", String.class);

        assertThat(indexes).contains("IX_TICKETS_CREATED", "IX_TICKETS_RESOLVED", "IX_TICKET_EVT_TYPE_CREATED");
    }
}
