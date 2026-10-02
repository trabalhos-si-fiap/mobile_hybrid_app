package com.edu.api.dashboard;

import com.edu.api.dashboard.controller.DashboardController;
import com.edu.api.support.ControllerSliceTest;
import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.AnomalyStatus;
import com.edu.api.dashboard.dto.CarrierDashboardResponse;
import com.edu.api.dashboard.dto.ChannelComparison;
import com.edu.api.dashboard.dto.DashboardResponse;
import com.edu.api.dashboard.dto.EducationalDashboardResponse;
import com.edu.api.dashboard.dto.LowStockProductResponse;
import com.edu.api.dashboard.dto.MetricComparison;
import com.edu.api.dashboard.dto.OmnichannelDashboardResponse;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.OperationalDashboardResponse;
import com.edu.api.dashboard.dto.RecentOccurrenceResponse;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import com.edu.api.dashboard.dto.SegmentSummary;
import com.edu.api.dashboard.dto.StudyActivityResponse;
import com.edu.api.dashboard.service.DashboardService;
import com.edu.api.dashboard.service.OmnichannelDashboardService;
import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.entity.OccurrenceType;
import com.edu.api.ticket.entity.Segment;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.startsWith;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

@ControllerSliceTest(DashboardController.class)
class DashboardControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private DashboardService dashboardService;

    @MockitoBean
    private OmnichannelDashboardService omnichannelDashboardService;

    private DashboardResponse validResponse() {

        StudyActivityResponse activity =
                new StudyActivityResponse(
                        LocalDate.now(),
                        5,
                        2
                );

        EducationalDashboardResponse educational =
                new EducationalDashboardResponse(
                        100L,
                        80L,
                        10L,
                        5L,
                        List.of(activity)
                );

        LowStockProductResponse lowStockProduct =
                new LowStockProductResponse(
                        1L,
                        "Produto Teste",
                        "EDU-12345678",
                        3,
                        10,
                        "LOW_STOCK"
                );

        CarrierDashboardResponse carrier =
                new CarrierDashboardResponse(
                        1L,
                        "Transportadora Teste",
                        new BigDecimal("4.5"),
                        new BigDecimal("95.0"),
                        5
                );

        RecentOccurrenceResponse occurrence =
                new RecentOccurrenceResponse(
                        1L,
                        OccurrenceType.DELIVERY_DELAY,
                        "Transportadora Teste",
                        Instant.now(),
                        OccurrenceStatus.OPEN
                );

        OperationalDashboardResponse operational =
                new OperationalDashboardResponse(
                        50L,
                        5L,
                        3L,
                        2L,
                        List.of(lowStockProduct),
                        List.of(carrier),
                        List.of(occurrence)
                );

        return new DashboardResponse(
                educational,
                operational,
                "Resumo executivo de teste"
        );
    }

    @Test
    void shouldGetDashboard() throws Exception {

        when(dashboardService.getDashboard(30))
                .thenReturn(validResponse());

        mockMvc.perform(
                get("/dashboard")
        )
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.educational.registeredStudents")
                .value(100))
        .andExpect(jsonPath("$.operational.registeredProducts")
                .value(50))
        .andExpect(jsonPath("$.executiveSummary")
                .value("Resumo executivo de teste"));

        verify(dashboardService).getDashboard(30);
    }

    @Test
    void shouldGetDashboardWithCustomDays() throws Exception {

        when(dashboardService.getDashboard(7))
                .thenReturn(validResponse());

        mockMvc.perform(
                get("/dashboard")
                        .param("days", "7")
        )
        .andExpect(status().isOk());

        verify(dashboardService).getDashboard(7);
    }

    @Test
    void shouldUseDefaultDays() throws Exception {

        when(dashboardService.getDashboard(30))
                .thenReturn(validResponse());

        mockMvc.perform(
                get("/dashboard")
        )
        .andExpect(status().isOk());

        verify(dashboardService).getDashboard(30);
    }

    @Test
    void shouldAcceptZeroDays() throws Exception {

        when(dashboardService.getDashboard(0))
                .thenReturn(validResponse());

        mockMvc.perform(
                get("/dashboard")
                        .param("days", "0")
        )
        .andExpect(status().isOk());

        verify(dashboardService).getDashboard(0);
    }

    private OmnichannelDashboardResponse omnichannelResponse() {
        MetricComparison opened = new MetricComparison(new BigDecimal("31"), new BigDecimal("24"),
                new BigDecimal("29.2"));
        MetricComparison none = new MetricComparison(null, null, null);
        OmnichannelKpis kpis = new OmnichannelKpis(opened, opened, 6, none, opened, none, none,
                new ChannelComparison(opened, none));
        SegmentSummary segment = new SegmentSummary(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", opened, opened,
                none, 2);
        SegmentAnomaly anomaly = new SegmentAnomaly(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", 12,
                new BigDecimal("3.4"), new BigDecimal("1.1"), new BigDecimal("7.82"), AnomalyStatus.ANOMALIA,
                AnomalyDirection.PICO, 28);
        return new OmnichannelDashboardResponse(7, Instant.parse("2026-09-25T15:00:00Z"),
                Instant.parse("2026-10-02T15:00:00Z"), kpis, List.of(segment), List.of(anomaly),
                List.of("Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,4."));
    }

    @Test
    void omnichannelDefaultsToSevenDays() throws Exception {
        when(omnichannelDashboardService.summary(7)).thenReturn(omnichannelResponse());

        mockMvc.perform(get("/dashboard/omnichannel"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.days").value(7))
                .andExpect(jsonPath("$.periodStart").value("2026-09-25T15:00:00Z"))
                .andExpect(jsonPath("$.kpis.opened.variation").value(29.2))
                .andExpect(jsonPath("$.kpis.backlog").value(6))
                .andExpect(jsonPath("$.kpis.slaMetPercentage.current").value(nullValue()))
                .andExpect(jsonPath("$.kpis.openedByChannel.app.current").value(31))
                .andExpect(jsonPath("$.segments[0].label").value("Problemas com pedido"))
                .andExpect(jsonPath("$.anomalies[0].last24h").value(12))
                .andExpect(jsonPath("$.anomalies[0].zScore").value(7.82))
                .andExpect(jsonPath("$.anomalies[0].status").value("ANOMALIA"))
                .andExpect(jsonPath("$.anomalies[0].direction").value("PICO"))
                .andExpect(jsonPath("$.highlights[0]").value(startsWith("Pico de tickets")));

        verify(omnichannelDashboardService).summary(7);
    }

    @Test
    void omnichannelAcceptsThirtyAndNinetyDays() throws Exception {
        when(omnichannelDashboardService.summary(30)).thenReturn(omnichannelResponse());
        when(omnichannelDashboardService.summary(90)).thenReturn(omnichannelResponse());

        mockMvc.perform(get("/dashboard/omnichannel").param("days", "30")).andExpect(status().isOk());
        mockMvc.perform(get("/dashboard/omnichannel").param("days", "90")).andExpect(status().isOk());

        verify(omnichannelDashboardService).summary(30);
        verify(omnichannelDashboardService).summary(90);
    }

    @Test
    void omnichannelRejectsOtherPeriods() throws Exception {
        for (String days : new String[] {"0", "15", "365"}) {
            mockMvc.perform(get("/dashboard/omnichannel").param("days", days))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"))
                    .andExpect(jsonPath("$.message").value("days: use 7, 30 ou 90"));
        }

        verifyNoInteractions(omnichannelDashboardService);
    }

    @Test
    void omnichannelRejectsANonNumericPeriod() throws Exception {
        mockMvc.perform(get("/dashboard/omnichannel").param("days", "abc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("BAD_REQUEST"));

        verifyNoInteractions(omnichannelDashboardService);
    }

    @Test
    void anEmptyPeriodFallsBackToSevenDays() throws Exception {
        when(omnichannelDashboardService.summary(7)).thenReturn(omnichannelResponse());

        mockMvc.perform(get("/dashboard/omnichannel").param("days", ""))
                .andExpect(status().isOk());

        verify(omnichannelDashboardService).summary(7);
    }

    @Test
    void anOracleFailureBecomesA500InTheApiErrorFormat() throws Exception {
        when(omnichannelDashboardService.summary(7))
                .thenThrow(new DataAccessResourceFailureException("ORA-06550"));

        mockMvc.perform(get("/dashboard/omnichannel"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.error").value("INTERNAL_ERROR"))
                .andExpect(jsonPath("$.message").value("Erro ao consultar o banco de dados."));
    }
}
