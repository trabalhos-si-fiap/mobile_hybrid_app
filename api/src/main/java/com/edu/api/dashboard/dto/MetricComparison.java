package com.edu.api.dashboard.dto;

import java.math.BigDecimal;

/** Valor no período, no período anterior e a variação (FN_CALC_TAXA_VARIACAO); todos podem ser nulos. */
public record MetricComparison(BigDecimal current, BigDecimal previous, BigDecimal variation) {
}
