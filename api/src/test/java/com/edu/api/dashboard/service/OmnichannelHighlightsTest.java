package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.AnomalyStatus;
import com.edu.api.dashboard.dto.ChannelComparison;
import com.edu.api.dashboard.dto.MetricComparison;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import com.edu.api.ticket.entity.Segment;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class OmnichannelHighlightsTest {

    private static final MetricComparison NONE = new MetricComparison(null, null, null);

    private final OmnichannelHighlights highlights = new OmnichannelHighlights();

    private static OmnichannelKpis kpis(String openedVariation, String slaPercentage) {
        MetricComparison opened = new MetricComparison(BigDecimal.TEN, BigDecimal.TEN,
                openedVariation == null ? null : new BigDecimal(openedVariation));
        MetricComparison sla = new MetricComparison(slaPercentage == null ? null : new BigDecimal(slaPercentage),
                null, null);
        return new OmnichannelKpis(opened, NONE, 0, sla, NONE, NONE, NONE, new ChannelComparison(NONE, NONE));
    }

    private static SegmentAnomaly anomaly(Segment segment, String label, long last24h, String mean,
                                          AnomalyDirection direction) {
        AnomalyStatus status = direction == null ? AnomalyStatus.NORMAL : AnomalyStatus.ANOMALIA;
        return new SegmentAnomaly(segment, label, last24h, new BigDecimal(mean), BigDecimal.ONE, null, status,
                direction, 28);
    }

    private static List<SegmentAnomaly> normal() {
        return List.of(anomaly(Segment.DEFEITO_APP, "Defeito no App / Problemas com App", 3, "3.5", null));
    }

    @Test
    void announcesASpike() {
        List<SegmentAnomaly> anomalies = List.of(
                anomaly(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", 12, "3.4", AnomalyDirection.PICO));

        assertThat(highlights.of(7, kpis(null, null), anomalies)).containsExactly(
                "Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,4.");
    }

    @Test
    void announcesADrop() {
        List<SegmentAnomaly> anomalies = List.of(
                anomaly(Segment.DEFEITO_APP, "Defeito no App / Problemas com App", 0, "11", AnomalyDirection.QUEDA));

        assertThat(highlights.of(7, kpis(null, null), anomalies)).containsExactly(
                "Queda de tickets em Defeito no App / Problemas com App: 0 nas últimas 24h, contra média de 11.");
    }

    @Test
    void reportsOpenedTicketsGoingUpFromTwentyPercent() {
        assertThat(highlights.of(30, kpis("20.0", null), normal())).containsExactly(
                "Tickets abertos subiram 20% em relação aos 30 dias anteriores.");
    }

    @Test
    void reportsOpenedTicketsGoingDown() {
        assertThat(highlights.of(7, kpis("-33.3", null), normal())).containsExactly(
                "Tickets abertos caíram 33,3% em relação aos 7 dias anteriores.");
    }

    @Test
    void ignoresSmallVariationsAndMissingBase() {
        assertThat(highlights.of(7, kpis("19.9", null), normal()))
                .containsExactly("Nenhum alerta no atendimento no período.");
        assertThat(highlights.of(7, kpis(null, null), normal()))
                .containsExactly("Nenhum alerta no atendimento no período.");
    }

    @Test
    void warnsWhenTheSlaIsBelowNinetyPercent() {
        assertThat(highlights.of(7, kpis(null, "88.9"), normal())).containsExactly(
                "SLA cumprido em 88,9% dos tickets resolvidos no período.");
        assertThat(highlights.of(7, kpis(null, "90"), normal()))
                .containsExactly("Nenhum alerta no atendimento no período.");
    }

    @Test
    void fallsBackWhenNothingStandsOut() {
        assertThat(highlights.of(90, kpis("5.0", "97.5"), List.of()))
                .containsExactly("Nenhum alerta no atendimento no período.");
    }

    @Test
    void keepsTheOrderAndAtMostFourLines() {
        List<SegmentAnomaly> anomalies = List.of(
                anomaly(Segment.DEFEITO_APP, "Defeito no App / Problemas com App", 9, "3.5", AnomalyDirection.PICO),
                anomaly(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", 0, "3.5", AnomalyDirection.QUEDA),
                anomaly(Segment.FEEDBACK_SUGESTAO, "Feedback / Sugestões", 8, "2.25", AnomalyDirection.PICO));

        assertThat(highlights.of(7, kpis("45.5", "80"), anomalies)).containsExactly(
                "Pico de tickets em Defeito no App / Problemas com App: 9 nas últimas 24h, contra média de 3,5.",
                "Queda de tickets em Problemas com pedido: 0 nas últimas 24h, contra média de 3,5.",
                "Pico de tickets em Feedback / Sugestões: 8 nas últimas 24h, contra média de 2,25.",
                "Tickets abertos subiram 45,5% em relação aos 7 dias anteriores.");
    }
}
