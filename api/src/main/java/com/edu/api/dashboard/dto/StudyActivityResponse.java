package com.edu.api.dashboard.dto;

import java.time.LocalDate;

public record StudyActivityResponse(
        LocalDate date,
        int studyActivities,
        int newRegistrations
) {
}