package com.edu.api.dashboard;

import com.edu.api.support.FullStackIntegration;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.springframework.http.HttpHeaders.AUTHORIZATION;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * O endpoint de ponta a ponta, lendo os cursores reais da PR_RESUMO_DASHBOARD.
 * Outros ITs podem ter deixado tickets no banco, então os números são
 * conferidos como mínimos, nunca exatos.
 */
class OmnichannelDashboardIT extends FullStackIntegration {

    @Test
    void summarizesTheAttendanceThroughThePlsql() throws Exception {
        long requester = fx.user("USER");
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_FILA")
                .createdAt(OffsetDateTime.now(ZoneOffset.UTC).minusHours(1)).insert();

        mockMvc.perform(get("/dashboard/omnichannel").param("days", "30")
                        .header(AUTHORIZATION, bearer(fx.user("EMPLOYEE"), "EMPLOYEE")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.days").value(30))
                .andExpect(jsonPath("$.periodEnd").isNotEmpty())
                .andExpect(jsonPath("$.kpis.opened.current", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.kpis.backlog", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.segments[*].segment")
                        .value(contains("DEFEITO_APP", "PROBLEMA_PEDIDO", "FEEDBACK_SUGESTAO")))
                .andExpect(jsonPath("$.anomalies[*].segment")
                        .value(contains("DEFEITO_APP", "PROBLEMA_PEDIDO", "FEEDBACK_SUGESTAO")))
                .andExpect(jsonPath("$.anomalies[1].last24h", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.highlights").isNotEmpty());
    }

    @Test
    void rejectsAnUnsupportedPeriod() throws Exception {
        mockMvc.perform(get("/dashboard/omnichannel").param("days", "15")
                        .header(AUTHORIZATION, bearer(fx.user("ADMIN"), "ADMIN")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"));
    }
}
