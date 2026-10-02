package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Frases de destaque do atendimento, por regra e nesta ordem: anomalias,
 * variação forte dos abertos, SLA abaixo da meta. No máximo quatro.
 */
@Component
public class OmnichannelHighlights {

    static final int MAX_LINES = 4;
    static final String NOTHING = "Nenhum alerta no atendimento no período.";

    private static final BigDecimal STRONG_VARIATION = BigDecimal.valueOf(20);
    private static final BigDecimal SLA_TARGET = BigDecimal.valueOf(90);
    private static final DecimalFormatSymbols PT_BR = DecimalFormatSymbols.getInstance(Locale.forLanguageTag("pt-BR"));

    public List<String> of(int days, OmnichannelKpis kpis, List<SegmentAnomaly> anomalies) {
        List<String> lines = new ArrayList<>();
        for (SegmentAnomaly anomaly : anomalies) {
            if (anomaly.direction() != null) {
                lines.add("%s de tickets em %s: %d nas últimas 24h, contra média de %s.".formatted(
                        anomaly.direction() == AnomalyDirection.PICO ? "Pico" : "Queda",
                        anomaly.label(), anomaly.last24h(), decimal(anomaly.mean())));
            }
        }

        BigDecimal opened = kpis.opened().variation();
        if (opened != null && opened.abs().compareTo(STRONG_VARIATION) >= 0) {
            lines.add("Tickets abertos %s %s%% em relação aos %d dias anteriores.".formatted(
                    opened.signum() > 0 ? "subiram" : "caíram", decimal(opened.abs()), days));
        }

        BigDecimal sla = kpis.slaMetPercentage().current();
        if (sla != null && sla.compareTo(SLA_TARGET) < 0) {
            lines.add("SLA cumprido em %s%% dos tickets resolvidos no período.".formatted(decimal(sla)));
        }

        if (lines.isEmpty()) {
            return List.of(NOTHING);
        }
        return List.copyOf(lines.subList(0, Math.min(MAX_LINES, lines.size())));
    }

    /** 3,4 · 29,2 · 20: vírgula decimal, sem zeros sobrando. */
    private static String decimal(BigDecimal value) {
        return new DecimalFormat("0.##", PT_BR).format(value);
    }
}
