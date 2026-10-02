package com.edu.api.db;

import com.edu.api.support.DashboardFixtures;
import com.edu.api.support.DashboardPlsql;
import com.edu.api.support.DashboardPlsql.Summary;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.Map;

import static com.edu.api.support.DashboardPlsql.number;
import static org.assertj.core.api.Assertions.assertThat;

/** Anomalias de volume da PR_RESUMO_DASHBOARD: últimas 24 h contra as 28 janelas de 24 h anteriores. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class DashboardAnomalyProcedureIT extends OracleIntegrationTest {

    private static final OffsetDateTime REF = DashboardFixtures.REF;

    @Autowired
    private JdbcTemplate jdbc;

    private DashboardFixtures dash;
    private DashboardPlsql plsql;

    @BeforeEach
    void setUp() {
        dash = new DashboardFixtures(jdbc);
        plsql = new DashboardPlsql(jdbc);
    }

    /** O primeiro ticket conhecido; as janelas de histórico só contam a partir dele. */
    private void firstTicketAt(OffsetDateTime at) {
        dash.opened("FEEDBACK_SUGESTAO", at, 1);
    }

    /** {@code count} tickets do segmento dentro da janela k (k = 0: as últimas 24 horas). */
    private void window(String segment, int k, int count) {
        dash.opened(segment, REF.minusDays(k).minusHours(1), count);
    }

    /** Uma contagem por janela de histórico, da janela 1 em diante. */
    private void history(String segment, int... counts) {
        for (int k = 1; k <= counts.length; k++) {
            window(segment, k, counts[k - 1]);
        }
    }

    private static int[] alternating(int odd, int even) {
        int[] counts = new int[28];
        for (int i = 0; i < counts.length; i++) {
            counts[i] = i % 2 == 0 ? odd : even;
        }
        return counts;
    }

    private static int[] flat(int value) {
        int[] counts = new int[28];
        Arrays.fill(counts, value);
        return counts;
    }

    private Map<String, Object> anomaly(String segment) {
        return plsql.summary(7, REF).anomaly(segment);
    }

    private static void assertNumber(Map<String, Object> row, String column, String expected) {
        if (expected == null) {
            assertThat(number(row, column)).as(column).isNull();
        } else {
            assertThat(number(row, column)).as(column).isEqualByComparingTo(expected);
        }
    }

    @Test
    void flagsASpikeInTheLast24Hours() {
        firstTicketAt(REF.minusDays(30));
        history("PROBLEMA_PEDIDO", alternating(3, 4));
        window("PROBLEMA_PEDIDO", 0, 9);
        dash.opened("PROBLEMA_PEDIDO", REF.minusHours(24), 1);
        dash.opened("PROBLEMA_PEDIDO", REF, 1);

        Summary summary = plsql.summary(7, REF);

        assertThat(summary.anomalies()).extracting(row -> row.get("segment"))
                .containsExactly("DEFEITO_APP", "PROBLEMA_PEDIDO", "FEEDBACK_SUGESTAO");
        Map<String, Object> order = summary.anomaly("PROBLEMA_PEDIDO");
        assertThat(order.get("label")).isEqualTo("Problemas com pedido");
        assertNumber(order, "atual", "10");
        assertNumber(order, "media", "3.5");
        assertNumber(order, "desvio", "0.51");
        assertNumber(order, "z_score", "12.77");
        assertNumber(order, "janelas", "28");
        assertThat(order.get("situacao")).isEqualTo("ANOMALIA");
    }

    @Test
    void flagsADrop() {
        firstTicketAt(REF.minusDays(30));
        history("DEFEITO_APP", alternating(10, 12));

        Map<String, Object> defect = anomaly("DEFEITO_APP");

        assertNumber(defect, "atual", "0");
        assertNumber(defect, "media", "11");
        assertNumber(defect, "desvio", "1.02");
        assertNumber(defect, "z_score", "-10.8");
        assertThat(defect.get("situacao")).isEqualTo("ANOMALIA");
    }

    @Test
    void anOrdinaryDayIsNormal() {
        firstTicketAt(REF.minusDays(30));
        history("PROBLEMA_PEDIDO", alternating(3, 4));
        window("PROBLEMA_PEDIDO", 0, 4);

        Map<String, Object> order = anomaly("PROBLEMA_PEDIDO");

        assertNumber(order, "z_score", "0.98");
        assertThat(order.get("situacao")).isEqualTo("NORMAL");
    }

    @Test
    void aFlatHistoryFlagsAnyDifference() {
        firstTicketAt(REF.minusDays(30));
        history("DEFEITO_APP", flat(2));
        window("DEFEITO_APP", 0, 2);
        history("PROBLEMA_PEDIDO", flat(2));
        window("PROBLEMA_PEDIDO", 0, 3);

        Summary summary = plsql.summary(7, REF);

        Map<String, Object> defect = summary.anomaly("DEFEITO_APP");
        assertNumber(defect, "desvio", "0");
        assertNumber(defect, "z_score", null);
        assertThat(defect.get("situacao")).isEqualTo("NORMAL");
        Map<String, Object> order = summary.anomaly("PROBLEMA_PEDIDO");
        assertNumber(order, "z_score", null);
        assertThat(order.get("situacao")).isEqualTo("ANOMALIA");
    }

    @Test
    void needsSevenWindowsOfHistory() {
        firstTicketAt(REF.minusDays(7));

        Map<String, Object> defect = anomaly("DEFEITO_APP");

        assertNumber(defect, "janelas", "6");
        assertNumber(defect, "media", null);
        assertNumber(defect, "desvio", null);
        assertNumber(defect, "z_score", null);
        assertThat(defect.get("situacao")).isEqualTo("SEM_HISTORICO");
    }

    @Test
    void sevenWindowsAreEnough() {
        firstTicketAt(REF.minusDays(8));

        Map<String, Object> defect = anomaly("DEFEITO_APP");

        assertNumber(defect, "janelas", "7");
        assertNumber(defect, "media", "0");
        assertThat(defect.get("situacao")).isEqualTo("NORMAL");
    }

    @Test
    void emptyWindowsCountAsZero() {
        firstTicketAt(REF.minusDays(30));
        window("DEFEITO_APP", 5, 7);

        Map<String, Object> defect = anomaly("DEFEITO_APP");

        assertNumber(defect, "janelas", "28");
        assertNumber(defect, "media", "0.25");
        assertNumber(defect, "desvio", "1.32");
        assertNumber(defect, "z_score", "-0.19");
        assertThat(defect.get("situacao")).isEqualTo("NORMAL");
    }
}
