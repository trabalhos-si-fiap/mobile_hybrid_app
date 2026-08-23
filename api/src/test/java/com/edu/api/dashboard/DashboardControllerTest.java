package com.edu.api.dashboard;

import com.edu.api.dashboard.dto.CarrierDashboardResponse;
import com.edu.api.dashboard.dto.DashboardResponse;
import com.edu.api.dashboard.dto.EducationalDashboardResponse;
import com.edu.api.dashboard.dto.LowStockProductResponse;
import com.edu.api.dashboard.dto.OperationalDashboardResponse;
import com.edu.api.dashboard.dto.RecentOccurrenceResponse;
import com.edu.api.dashboard.dto.StudyActivityResponse;
import com.edu.api.dashboard.service.DashboardService;
import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.entity.OccurrenceType;
import com.edu.api.security.TestSecurityConfig;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(TestSecurityConfig.class)
class DashboardControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private DashboardService dashboardService;

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
}