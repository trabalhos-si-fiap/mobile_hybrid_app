package com.edu.api.dashboard.dto;

import java.time.Instant;
import java.util.List;

public record OmnichannelDashboardResponse(
        int days,
        Instant periodStart,
        Instant periodEnd,
        OmnichannelKpis kpis,
        List<SegmentSummary> segments,
        List<SegmentAnomaly> anomalies,
        List<String> highlights
) {
}
