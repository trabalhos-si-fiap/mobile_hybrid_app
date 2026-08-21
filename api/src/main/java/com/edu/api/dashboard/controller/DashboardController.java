package com.edu.api.dashboard.controller;

import com.edu.api.dashboard.dto.DashboardResponse;
import com.edu.api.dashboard.service.DashboardService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/dashboard")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        System.out.println(">>> DASHBOARD CONTROLLER CRIADO <<<");
        this.dashboardService = dashboardService;
    }

    @GetMapping
    public DashboardResponse getDashboard(
            @RequestParam(defaultValue = "30") int days
    ) {
        return dashboardService.getDashboard(days);
    }
}