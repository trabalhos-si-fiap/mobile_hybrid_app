package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.Location;
import org.flywaydb.core.api.MigrationInfo;
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
class FlywayMigrationIT extends OracleIntegrationTest {

    @Autowired
    private Flyway flyway;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void migrationsSucceedWithoutSeed() {
        MigrationInfo[] applied = flyway.info().applied();

        assertThat(applied).isNotEmpty();
        assertThat(applied).allSatisfy(m -> assertThat(m.getState().isFailed()).isFalse());
        // Pela pasta, não pelo nome: um seed sem "seed" no nome também é pego.
        assertThat(flyway.getConfiguration().getLocations())
                .extracting(Location::getPath)
                .noneMatch(path -> path.contains("db/seed"));
        assertThat(applied).extracting(MigrationInfo::getPhysicalLocation)
                .noneMatch(location -> location.replace('\\', '/').contains("/db/seed/"));
    }

    @Test
    void createsApplicationTables() {
        List<String> tables = jdbc.queryForList(
                "SELECT LOWER(table_name) FROM user_tables", String.class);

        assertThat(tables).contains(
                "products", "inventories", "inventory_adjustments",
                "carriers", "carrier_occurrences", "admin_users",
                "skills", "employees", "employee_skills", "ticket_tipo_config",
                "tickets", "ticket_messages", "ticket_attachments", "ticket_events", "notifications");
        assertThat(tables).doesNotContain("student_metrics");
    }

    @Test
    void namesKeyConstraintsExplicitly() {
        List<String> unnamed = jdbc.queryForList(
                "SELECT table_name || '.' || constraint_name FROM user_constraints "
                        + "WHERE constraint_type IN ('P', 'U', 'R') AND constraint_name LIKE 'SYS\\_C%' ESCAPE '\\'",
                String.class);
        assertThat(unnamed).isEmpty();

        List<String> productChecks = jdbc.queryForList(
                "SELECT constraint_name FROM user_constraints WHERE table_name = 'PRODUCTS'",
                String.class);
        assertThat(productChecks).contains(
                "PK_PRODUCTS", "UQ_PRODUCTS_SKU", "CK_PRODUCTS_MINIMUM_STOCK", "CK_PRODUCTS_PRICE");
    }
}
