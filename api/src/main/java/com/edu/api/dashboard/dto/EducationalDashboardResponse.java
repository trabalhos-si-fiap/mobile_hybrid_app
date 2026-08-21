package com.edu.api.dashboard.dto;

import java.util.List;

public record EducationalDashboardResponse(
        long registeredStudents,
        long activeStudents,
        long newRegistrations,
        long inactiveRiskStudents,
        List<StudyActivityResponse> activityHistory
) {
}