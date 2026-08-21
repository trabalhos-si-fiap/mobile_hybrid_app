package com.edu.api.dashboard.provider;

import com.edu.api.dashboard.dto.EducationalDashboardResponse;
import com.edu.api.dashboard.dto.StudyActivityResponse;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;

@Component
public class EducationalMetricsProvider {

    public EducationalDashboardResponse getMetrics(int days) {

        List<StudyActivityResponse> activityHistory = List.of(
                new StudyActivityResponse(
                        LocalDate.now().minusDays(4),
                        35,
                        2
                ),
                new StudyActivityResponse(
                        LocalDate.now().minusDays(3),
                        42,
                        1
                ),
                new StudyActivityResponse(
                        LocalDate.now().minusDays(2),
                        38,
                        3
                ),
                new StudyActivityResponse(
                        LocalDate.now().minusDays(1),
                        47,
                        2
                ),
                new StudyActivityResponse(
                        LocalDate.now(),
                        51,
                        4
                )
        );

        return new EducationalDashboardResponse(
                128, // alunos cadastrados
                84,  // alunos ativos
                12,  // novos cadastros
                9,   // risco de inatividade
                activityHistory
        );
    }
}