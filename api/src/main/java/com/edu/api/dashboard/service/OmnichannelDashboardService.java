package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.AnomalyStatus;
import com.edu.api.dashboard.dto.ChannelComparison;
import com.edu.api.dashboard.dto.MetricComparison;
import com.edu.api.dashboard.dto.OmnichannelDashboardResponse;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import com.edu.api.dashboard.dto.SegmentSummary;
import com.edu.api.dashboard.plsql.DashboardProcedures;
import com.edu.api.dashboard.plsql.DashboardSummaryRows;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.AnomalyLine;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.Kpi;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.SegmentLine;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Dashboard do atendimento: o cálculo é da PR_RESUMO_DASHBOARD; aqui só se monta a resposta. */
@Service
public class OmnichannelDashboardService {

    /** Períodos aceitos, em dias. */
    public static final Set<Integer> PERIODS = Set.of(7, 30, 90);

    private final DashboardProcedures procedures;
    private final OmnichannelHighlights highlights;
    private final Clock clock;

    public OmnichannelDashboardService(DashboardProcedures procedures, OmnichannelHighlights highlights,
                                       Clock clock) {
        this.procedures = procedures;
        this.highlights = highlights;
        this.clock = clock;
    }

    public OmnichannelDashboardResponse summary(int days) {
        Instant reference = clock.instant();
        DashboardSummaryRows rows = procedures.summary(days, reference);

        Map<String, Kpi> byMetric = rows.kpis().stream()
                .collect(Collectors.toMap(Kpi::metric, Function.identity()));
        OmnichannelKpis kpis = new OmnichannelKpis(
                comparison(byMetric.get("ABERTOS")),
                comparison(byMetric.get("RESOLVIDOS")),
                byMetric.get("BACKLOG").current().longValue(),
                comparison(byMetric.get("SLA_CUMPRIDO_PCT")),
                comparison(byMetric.get("ESCALADOS")),
                comparison(byMetric.get("TEMPO_MEDIO_ASSUMIR_MIN")),
                comparison(byMetric.get("TEMPO_MEDIO_RESOLUCAO_H")),
                new ChannelComparison(comparison(byMetric.get("ABERTOS_APP")),
                        comparison(byMetric.get("ABERTOS_CHATBOT"))));
        List<SegmentSummary> segments = rows.segments().stream()
                .map(OmnichannelDashboardService::segment)
                .toList();
        List<SegmentAnomaly> anomalies = rows.anomalies().stream()
                .map(OmnichannelDashboardService::anomaly)
                .toList();

        return new OmnichannelDashboardResponse(days, reference.minus(Duration.ofDays(days)), reference, kpis,
                segments, anomalies, highlights.of(days, kpis, anomalies));
    }

    private static MetricComparison comparison(Kpi kpi) {
        return new MetricComparison(kpi.current(), kpi.previous(), kpi.variation());
    }

    private static SegmentSummary segment(SegmentLine line) {
        return new SegmentSummary(line.segment(), line.label(),
                new MetricComparison(line.opened(), line.openedPrevious(), line.openedVariation()),
                new MetricComparison(line.resolved(), line.resolvedPrevious(), line.resolvedVariation()),
                new MetricComparison(line.slaPct(), line.slaPctPrevious(), line.slaPctVariation()),
                line.backlog());
    }

    private static SegmentAnomaly anomaly(AnomalyLine line) {
        AnomalyStatus status = AnomalyStatus.valueOf(line.situation());
        return new SegmentAnomaly(line.segment(), line.label(), line.current(), line.mean(), line.deviation(),
                line.zScore(), status, direction(status, line.current(), line.mean()), line.windows());
    }

    /** Pico ou queda conforme o volume atual fica acima ou abaixo da média; só numa ANOMALIA. */
    private static AnomalyDirection direction(AnomalyStatus status, long current, BigDecimal mean) {
        if (status != AnomalyStatus.ANOMALIA || mean == null) {
            return null;
        }
        return BigDecimal.valueOf(current).compareTo(mean) > 0 ? AnomalyDirection.PICO : AnomalyDirection.QUEDA;
    }
}
