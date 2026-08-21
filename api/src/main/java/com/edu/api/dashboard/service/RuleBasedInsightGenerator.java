package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.EducationalDashboardResponse;
import com.edu.api.dashboard.dto.OperationalDashboardResponse;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

@Component
public class RuleBasedInsightGenerator implements InsightGenerator {

    @Override
    public String generate(
            EducationalDashboardResponse educational,
            OperationalDashboardResponse operational
    ) {

        List<String> insights = new ArrayList<>();

        long registered = educational.registeredStudents();
        long active = educational.activeStudents();

        if (registered > 0) {
            long percentage = Math.round(
                    (active * 100.0) / registered
            );

            insights.add(
                    percentage + "% dos alunos estiveram ativos no período."
            );
        }

        if (educational.inactiveRiskStudents() > 0) {
            insights.add(
                    educational.inactiveRiskStudents()
                            + " alunos apresentam risco de inatividade."
            );
        }

        if (operational.lowStockProducts() > 0) {
            insights.add(
                    "Há "
                            + operational.lowStockProducts()
                            + " produtos abaixo do estoque mínimo."
            );
        }

        if (operational.openOccurrences() > 0) {
            insights.add(
                    operational.openOccurrences()
                            + " ocorrências estão abertas."
            );
        }

        if (insights.isEmpty()) {
            return "Nenhum alerta relevante foi identificado no período.";
        }

        return String.join(" ", insights);
    }
}