package com.edu.api.dashboard.dto;

import com.edu.api.ticket.entity.Segment;

import java.math.BigDecimal;

/** Volume das últimas 24 h contra as janelas de 24 h anteriores; direction só existe numa ANOMALIA. */
public record SegmentAnomaly(
        Segment segment,
        String label,
        long last24h,
        BigDecimal mean,
        BigDecimal standardDeviation,
        BigDecimal zScore,
        AnomalyStatus status,
        AnomalyDirection direction,
        int windows
) {
}
