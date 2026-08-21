package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.EducationalDashboardResponse;
import com.edu.api.dashboard.dto.OperationalDashboardResponse;

public interface InsightGenerator {

    String generate(
            EducationalDashboardResponse educational,
            OperationalDashboardResponse operational
    );
}