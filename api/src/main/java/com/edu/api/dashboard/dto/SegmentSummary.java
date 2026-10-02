package com.edu.api.dashboard.dto;

import com.edu.api.ticket.entity.Segment;

public record SegmentSummary(
        Segment segment,
        String label,
        MetricComparison opened,
        MetricComparison resolved,
        MetricComparison slaMetPercentage,
        long backlog
) {
}
