package com.edu.api.dashboard.dto;

/** Indicadores do período; o backlog é uma foto do momento, sem comparação. */
public record OmnichannelKpis(
        MetricComparison opened,
        MetricComparison resolved,
        long backlog,
        MetricComparison slaMetPercentage,
        MetricComparison escalated,
        MetricComparison averageMinutesToAssume,
        MetricComparison averageHoursToResolve,
        ChannelComparison openedByChannel
) {
}
