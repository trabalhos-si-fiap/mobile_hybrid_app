package com.edu.api.dashboard.plsql;

import com.edu.api.ticket.entity.Segment;

import java.math.BigDecimal;
import java.util.List;

/** As linhas dos três cursores da PR_RESUMO_DASHBOARD, sem interpretação. */
public record DashboardSummaryRows(List<Kpi> kpis, List<SegmentLine> segments, List<AnomalyLine> anomalies) {

    /** Uma linha de p_kpis; no BACKLOG, previous e variation vêm nulos. */
    public record Kpi(String metric, BigDecimal current, BigDecimal previous, BigDecimal variation) {
    }

    public record SegmentLine(Segment segment, String label,
                              BigDecimal opened, BigDecimal openedPrevious, BigDecimal openedVariation,
                              BigDecimal resolved, BigDecimal resolvedPrevious, BigDecimal resolvedVariation,
                              BigDecimal slaPct, BigDecimal slaPctPrevious, BigDecimal slaPctVariation,
                              long backlog) {
    }

    /** situation: NORMAL, ANOMALIA ou SEM_HISTORICO; mean, deviation e zScore podem vir nulos. */
    public record AnomalyLine(Segment segment, String label, long current, BigDecimal mean,
                              BigDecimal deviation, BigDecimal zScore, String situation, int windows) {
    }
}
