package com.edu.api.dashboard.controller;

import com.edu.api.dashboard.dto.DashboardResponse;
import com.edu.api.dashboard.dto.OmnichannelDashboardResponse;
import com.edu.api.dashboard.service.DashboardService;
import com.edu.api.dashboard.service.OmnichannelDashboardService;
import com.edu.api.shared.exception.ValidationException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/dashboard")
public class DashboardController {

    private final DashboardService dashboardService;
    private final OmnichannelDashboardService omnichannelDashboardService;

    public DashboardController(DashboardService dashboardService,
                               OmnichannelDashboardService omnichannelDashboardService) {
        this.dashboardService = dashboardService;
        this.omnichannelDashboardService = omnichannelDashboardService;
    }

    @GetMapping
    public DashboardResponse getDashboard(
            @RequestParam(defaultValue = "30") int days
    ) {
        return dashboardService.getDashboard(days);
    }

    /** Resumo do atendimento omnichannel (PR_RESUMO_DASHBOARD) nos últimos 7, 30 ou 90 dias. */
    @GetMapping("/omnichannel")
    public OmnichannelDashboardResponse getOmnichannel(@RequestParam(defaultValue = "7") int days) {
        if (!OmnichannelDashboardService.PERIODS.contains(days)) {
            throw new ValidationException("days: use 7, 30 ou 90");
        }
        return omnichannelDashboardService.summary(days);
    }
}
