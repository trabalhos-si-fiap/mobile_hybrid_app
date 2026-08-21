package com.edu.api.dashboard.dto;

public record DashboardResponse(
        EducationalDashboardResponse educational,
        OperationalDashboardResponse operational,
        String executiveSummary
) {
}