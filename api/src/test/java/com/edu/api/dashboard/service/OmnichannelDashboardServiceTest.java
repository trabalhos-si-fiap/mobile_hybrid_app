package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.AnomalyStatus;
import com.edu.api.dashboard.dto.OmnichannelDashboardResponse;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import com.edu.api.dashboard.dto.SegmentSummary;
import com.edu.api.dashboard.plsql.DashboardProcedures;
import com.edu.api.dashboard.plsql.DashboardSummaryRows;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.AnomalyLine;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.Kpi;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.SegmentLine;
import com.edu.api.ticket.entity.Segment;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class OmnichannelDashboardServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-02T15:00:00Z");

    private final DashboardProcedures procedures = mock(DashboardProcedures.class);
    private OmnichannelDashboardService service;

    @BeforeEach
    void setUp() {
        service = new OmnichannelDashboardService(procedures, new OmnichannelHighlights(),
                Clock.fixed(NOW, ZoneOffset.UTC));
        when(procedures.summary(7, NOW)).thenReturn(rows());
    }

    private static BigDecimal n(String value) {
        return value == null ? null : new BigDecimal(value);
    }

    private static Kpi kpi(String metric, String current, String previous, String variation) {
        return new Kpi(metric, n(current), n(previous), n(variation));
    }

    private static AnomalyLine anomaly(Segment segment, String label, long current, String mean, String situation) {
        return new AnomalyLine(segment, label, current, n(mean), mean == null ? null : n("1.14"),
                mean == null ? null : n("0.44"), situation, mean == null ? 3 : 28);
    }

    private static DashboardSummaryRows rows() {
        List<Kpi> kpis = List.of(
                kpi("ABERTOS", "31", "24", "29.2"),
                kpi("RESOLVIDOS", "27", "25", "8"),
                kpi("BACKLOG", "6", null, null),
                kpi("SLA_CUMPRIDO_PCT", "88.9", "92", "-3.4"),
                kpi("ESCALADOS", "2", "3", "-33.3"),
                kpi("TEMPO_MEDIO_ASSUMIR_MIN", "14.5", "18", "-19.4"),
                kpi("TEMPO_MEDIO_RESOLUCAO_H", null, null, null),
                kpi("ABERTOS_APP", "26", "21", "23.8"),
                kpi("ABERTOS_CHATBOT", "5", "3", "66.7"));
        List<SegmentLine> segments = List.of(
                new SegmentLine(Segment.DEFEITO_APP, "Defeito no App / Problemas com App",
                        n("10"), n("8"), n("25"), n("9"), n("9"), n("0"), n("88.9"), n("100"), n("-11.1"), 2),
                new SegmentLine(Segment.PROBLEMA_PEDIDO, "Problemas com pedido",
                        n("15"), n("10"), n("50"), n("12"), n("10"), n("20"), n("91.7"), n("90"), n("1.9"), 3),
                new SegmentLine(Segment.FEEDBACK_SUGESTAO, "Feedback / Sugestões",
                        n("6"), n("6"), n("0"), n("6"), n("6"), n("0"), null, null, null, 1));
        List<AnomalyLine> anomalies = List.of(
                anomaly(Segment.DEFEITO_APP, "Defeito no App / Problemas com App", 0, "11", "ANOMALIA"),
                anomaly(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", 12, "3.5", "ANOMALIA"),
                anomaly(Segment.FEEDBACK_SUGESTAO, "Feedback / Sugestões", 2, null, "SEM_HISTORICO"));
        return new DashboardSummaryRows(kpis, segments, anomalies);
    }

    @Test
    void asksTheProcedureForThePeriodEndingNow() {
        OmnichannelDashboardResponse response = service.summary(7);

        verify(procedures).summary(7, NOW);
        assertThat(response.days()).isEqualTo(7);
        assertThat(response.periodEnd()).isEqualTo(NOW);
        assertThat(response.periodStart()).isEqualTo(Instant.parse("2026-09-25T15:00:00Z"));
    }

    @Test
    void mapsTheKpisAndTheChannels() {
        OmnichannelKpis kpis = service.summary(7).kpis();

        assertThat(kpis.opened().current()).isEqualByComparingTo("31");
        assertThat(kpis.opened().variation()).isEqualByComparingTo("29.2");
        assertThat(kpis.resolved().previous()).isEqualByComparingTo("25");
        assertThat(kpis.backlog()).isEqualTo(6);
        assertThat(kpis.slaMetPercentage().current()).isEqualByComparingTo("88.9");
        assertThat(kpis.escalated().variation()).isEqualByComparingTo("-33.3");
        assertThat(kpis.averageMinutesToAssume().current()).isEqualByComparingTo("14.5");
        assertThat(kpis.averageHoursToResolve().current()).isNull();
        assertThat(kpis.openedByChannel().app().current()).isEqualByComparingTo("26");
        assertThat(kpis.openedByChannel().chatbot().variation()).isEqualByComparingTo("66.7");
    }

    @Test
    void mapsTheSegments() {
        List<SegmentSummary> segments = service.summary(7).segments();

        assertThat(segments).extracting(SegmentSummary::segment)
                .containsExactly(Segment.DEFEITO_APP, Segment.PROBLEMA_PEDIDO, Segment.FEEDBACK_SUGESTAO);
        SegmentSummary order = segments.get(1);
        assertThat(order.label()).isEqualTo("Problemas com pedido");
        assertThat(order.opened().variation()).isEqualByComparingTo("50");
        assertThat(order.resolved().current()).isEqualByComparingTo("12");
        assertThat(order.slaMetPercentage().previous()).isEqualByComparingTo("90");
        assertThat(order.backlog()).isEqualTo(3);
        assertThat(segments.get(2).slaMetPercentage().current()).isNull();
    }

    @Test
    void givesEachAnomalyItsDirection() {
        List<SegmentAnomaly> anomalies = service.summary(7).anomalies();

        assertThat(anomalies).extracting(SegmentAnomaly::status)
                .containsExactly(AnomalyStatus.ANOMALIA, AnomalyStatus.ANOMALIA, AnomalyStatus.SEM_HISTORICO);
        assertThat(anomalies).extracting(SegmentAnomaly::direction)
                .containsExactly(AnomalyDirection.QUEDA, AnomalyDirection.PICO, null);
        SegmentAnomaly order = anomalies.get(1);
        assertThat(order.last24h()).isEqualTo(12);
        assertThat(order.mean()).isEqualByComparingTo("3.5");
        assertThat(order.standardDeviation()).isEqualByComparingTo("1.14");
        assertThat(order.windows()).isEqualTo(28);
        assertThat(anomalies.get(2).mean()).isNull();
    }

    @Test
    void buildsTheHighlightsFromTheMappedData() {
        assertThat(service.summary(7).highlights()).containsExactly(
                "Queda de tickets em Defeito no App / Problemas com App: 0 nas últimas 24h, contra média de 11.",
                "Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,5.",
                "Tickets abertos subiram 29,2% em relação aos 7 dias anteriores.",
                "SLA cumprido em 88,9% dos tickets resolvidos no período.");
    }
}
