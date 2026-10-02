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
import java.time.ZoneOffset;
import java.util.Map;

import static com.edu.api.support.DashboardPlsql.number;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Indicadores e segmentos da PR_RESUMO_DASHBOARD, com a referência fixa em 2001. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class DashboardSummaryProcedureIT extends OracleIntegrationTest {

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

    private Summary week() {
        return plsql.summary(7, REF);
    }

    private static void assertMetric(Map<String, Object> row, String current, String previous, String variation) {
        assertNumber(row, "atual", current);
        assertNumber(row, "anterior", previous);
        assertNumber(row, "variacao", variation);
    }

    private static void assertNumber(Map<String, Object> row, String column, String expected) {
        if (expected == null) {
            assertThat(number(row, column)).as(column).isNull();
        } else {
            assertThat(number(row, column)).as(column).isEqualByComparingTo(expected);
        }
    }

    @Test
    void listsTheMetricsInOrder() {
        assertThat(week().kpis()).extracting(row -> row.get("metrica")).containsExactly(
                "ABERTOS", "RESOLVIDOS", "BACKLOG", "SLA_CUMPRIDO_PCT", "ESCALADOS",
                "TEMPO_MEDIO_ASSUMIR_MIN", "TEMPO_MEDIO_RESOLUCAO_H", "ABERTOS_APP", "ABERTOS_CHATBOT");
    }

    @Test
    void countsOpenedTicketsInsideEachWindow() {
        dash.ticket("DEFEITO_APP", REF.minusMinutes(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(7)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(7).minusSeconds(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(14)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(14).minusSeconds(1)).insert();
        dash.ticket("DEFEITO_APP", REF).insert();

        assertMetric(week().kpi("ABERTOS"), "2", "2", "0");
    }

    @Test
    void comparesInstantsWhateverTheTimeZone() {
        ZoneOffset saoPaulo = ZoneOffset.ofHours(-3);
        dash.ticket("DEFEITO_APP", REF.minusDays(7).withOffsetSameInstant(saoPaulo)).insert();
        dash.ticket("DEFEITO_APP", REF.withOffsetSameInstant(saoPaulo)).insert();
        OffsetDateTime created = REF.minusDays(2);
        dash.ticket("PROBLEMA_PEDIDO", created).status("RESOLVIDO")
                .resolvedAt(created.plusHours(3).withOffsetSameInstant(ZoneOffset.ofHours(5))).insert();

        Summary summary = week();

        assertMetric(summary.kpi("ABERTOS"), "2", "0", null);
        assertNumber(summary.kpi("TEMPO_MEDIO_RESOLUCAO_H"), "atual", "3");
    }

    @Test
    void resolvedCountsOnlyResolvedOrClosedTickets() {
        dash.ticket("DEFEITO_APP", REF.minusDays(2)).status("RESOLVIDO").resolvedAt(REF.minusDays(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(3)).status("FECHADO").resolvedAt(REF.minusDays(2)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(2)).status("EM_ATENDIMENTO").resolvedAt(REF.minusDays(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(9)).status("RESOLVIDO").resolvedAt(REF.minusDays(8)).insert();

        assertMetric(week().kpi("RESOLVIDOS"), "2", "1", "100");
    }

    @Test
    void aReopenedTicketLeavesTheResolvedAndReturnsToTheBacklog() {
        long ticket = dash.ticket("DEFEITO_APP", REF.minusDays(3)).status("EM_ATENDIMENTO").insert();
        dash.event(ticket, "RESOLVIDO", REF.minusDays(2));
        dash.event(ticket, "REABERTO", REF.minusDays(1));

        Summary summary = week();

        assertMetric(summary.kpi("RESOLVIDOS"), "0", "0", null);
        assertNumber(summary.kpi("BACKLOG"), "atual", "1");
    }

    @Test
    void slaPercentageFollowsTheSlaFunction() {
        OffsetDateTime created = REF.minusDays(2);
        dash.ticket("DEFEITO_APP", created).status("RESOLVIDO").slaDueAt(created.plusHours(4))
                .resolvedAt(created.plusHours(1)).insert();
        dash.ticket("DEFEITO_APP", created).status("FECHADO").slaDueAt(created.plusHours(4))
                .resolvedAt(created.plusHours(2)).insert();
        dash.ticket("DEFEITO_APP", created).status("FECHADO").slaDueAt(created.plusHours(4))
                .resolvedAt(created.plusHours(5)).insert();
        OffsetDateTime before = REF.minusDays(9);
        dash.ticket("DEFEITO_APP", before).status("FECHADO").slaDueAt(before.plusHours(4))
                .resolvedAt(before.plusHours(1)).insert();

        assertMetric(week().kpi("SLA_CUMPRIDO_PCT"), "66.7", "100", "-33.3");
    }

    @Test
    void countsEscalationEvents() {
        long ticket = dash.ticket("PROBLEMA_PEDIDO", REF.minusDays(20)).insert();
        dash.event(ticket, "ESCALADO", REF.minusDays(1));
        dash.event(ticket, "ESCALADO", REF.minusDays(2));
        dash.event(ticket, "ESCALADO", REF.minusDays(10));
        dash.event(ticket, "ALERTA_ENGENHARIA", REF.minusDays(1));

        assertMetric(week().kpi("ESCALADOS"), "2", "1", "100");
    }

    @Test
    void averagesTheTimeToAssumeAndToResolve() {
        OffsetDateTime first = REF.minusDays(2);
        OffsetDateTime second = REF.minusDays(3);
        OffsetDateTime before = REF.minusDays(9);
        dash.ticket("DEFEITO_APP", first).status("RESOLVIDO")
                .assumedAt(first.plusMinutes(10)).resolvedAt(first.plusHours(2)).insert();
        dash.ticket("DEFEITO_APP", second).status("FECHADO")
                .assumedAt(second.plusMinutes(20)).resolvedAt(second.plusHours(4)).insert();
        dash.ticket("DEFEITO_APP", before).status("FECHADO")
                .assumedAt(before.plusMinutes(30)).resolvedAt(before.plusHours(6)).insert();

        Summary summary = week();

        assertMetric(summary.kpi("TEMPO_MEDIO_ASSUMIR_MIN"), "15", "30", "-50");
        assertMetric(summary.kpi("TEMPO_MEDIO_RESOLUCAO_H"), "3", "6", "-50");
    }

    @Test
    void measuresResolutionsLongerThanNinetyNineDays() {
        dash.ticket("FEEDBACK_SUGESTAO", REF.minusDays(200)).status("FECHADO")
                .resolvedAt(REF.minusDays(10)).insert();

        Summary quarter = plsql.summary(90, REF);

        assertNumber(quarter.kpi("RESOLVIDOS"), "atual", "1");
        assertNumber(quarter.kpi("TEMPO_MEDIO_RESOLUCAO_H"), "atual", "4560");
    }

    @Test
    void splitsOpenedTicketsByChannel() {
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(2)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).channel("CHATBOT_IA").insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(8)).insert();

        Summary summary = week();

        assertMetric(summary.kpi("ABERTOS_APP"), "2", "1", "100");
        assertMetric(summary.kpi("ABERTOS_CHATBOT"), "1", "0", null);
    }

    @Test
    void backlogIsASnapshotOfUnfinishedTickets() {
        dash.ticket("DEFEITO_APP", REF.minusDays(200)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).status("EM_ATENDIMENTO").insert();
        dash.ticket("PROBLEMA_PEDIDO", REF.minusHours(1)).status("ESCALADO").insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).status("RESOLVIDO").resolvedAt(REF.minusHours(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(2)).status("FECHADO").resolvedAt(REF.minusDays(1)).insert();
        dash.ticket("DEFEITO_APP", REF.plusHours(1)).insert();

        assertMetric(week().kpi("BACKLOG"), "3", null, null);
    }

    @Test
    void leavesNullsWhereThereIsNoBase() {
        Summary summary = week();

        assertMetric(summary.kpi("ABERTOS"), "0", "0", null);
        assertMetric(summary.kpi("SLA_CUMPRIDO_PCT"), null, null, null);
        assertMetric(summary.kpi("TEMPO_MEDIO_ASSUMIR_MIN"), null, null, null);
        assertMetric(summary.kpi("TEMPO_MEDIO_RESOLUCAO_H"), null, null, null);
        assertMetric(summary.kpi("BACKLOG"), "0", null, null);
    }

    @Test
    void windowsFollowTheChosenPeriod() {
        dash.ticket("DEFEITO_APP", REF.minusDays(20)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(50)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(100)).insert();

        assertMetric(plsql.summary(7, REF).kpi("ABERTOS"), "0", "0", null);
        assertMetric(plsql.summary(30, REF).kpi("ABERTOS"), "1", "1", "0");
        assertMetric(plsql.summary(90, REF).kpi("ABERTOS"), "2", "1", "100");
    }

    @Test
    void segmentsComeInEnumOrderWithZeros() {
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).insert();

        Summary summary = week();

        assertThat(summary.segments()).extracting(row -> row.get("segment"))
                .containsExactly("DEFEITO_APP", "PROBLEMA_PEDIDO", "FEEDBACK_SUGESTAO");
        Map<String, Object> order = summary.segment("PROBLEMA_PEDIDO");
        assertThat(order.get("label")).isEqualTo("Problemas com pedido");
        assertNumber(order, "abertos", "0");
        assertNumber(order, "abertos_anterior", "0");
        assertNumber(order, "abertos_variacao", null);
        assertNumber(order, "sla_pct", null);
        assertNumber(order, "backlog", "0");
        assertNumber(summary.segment("DEFEITO_APP"), "abertos", "1");
        assertNumber(summary.segment("DEFEITO_APP"), "backlog", "1");
    }

    @Test
    void segmentRowsCompareTheTwoWindows() {
        dash.ticket("PROBLEMA_PEDIDO", REF.minusDays(1)).insert();
        OffsetDateTime created = REF.minusDays(2);
        dash.ticket("PROBLEMA_PEDIDO", created).status("RESOLVIDO").slaDueAt(created.plusDays(2))
                .resolvedAt(REF.minusDays(1)).insert();
        OffsetDateTime before = REF.minusDays(9);
        dash.ticket("PROBLEMA_PEDIDO", before).status("FECHADO").slaDueAt(before.plusHours(1))
                .resolvedAt(REF.minusDays(8)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).insert();

        Map<String, Object> order = week().segment("PROBLEMA_PEDIDO");

        assertNumber(order, "abertos", "2");
        assertNumber(order, "abertos_anterior", "1");
        assertNumber(order, "abertos_variacao", "100");
        assertNumber(order, "resolvidos", "1");
        assertNumber(order, "resolvidos_anterior", "1");
        assertNumber(order, "resolvidos_variacao", "0");
        assertNumber(order, "sla_pct", "100");
        assertNumber(order, "sla_pct_anterior", "0");
        assertNumber(order, "sla_pct_variacao", null);
        assertNumber(order, "backlog", "1");
    }

    @Test
    void rejectsAnInvalidPeriod() {
        assertThatThrownBy(() -> plsql.summary(15, REF)).hasMessageContaining("ORA-20004");
        assertThatThrownBy(() -> plsql.summary(0, REF)).hasMessageContaining("ORA-20004");
    }
}
