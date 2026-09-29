package com.edu.api.employee.controller;

import com.edu.api.employee.dto.EmployeeMeResponse;
import com.edu.api.employee.dto.PresenceRequest;
import com.edu.api.employee.service.EmployeeService;
import com.edu.api.security.AuthenticatedUser;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/employees")
public class EmployeeController {

    private final EmployeeService employees;

    public EmployeeController(EmployeeService employees) {
        this.employees = employees;
    }

    @GetMapping("/me")
    public EmployeeMeResponse me(@AuthenticationPrincipal AuthenticatedUser user) {
        return employees.me(user);
    }

    @PutMapping("/me/presence")
    public EmployeeMeResponse changePresence(@AuthenticationPrincipal AuthenticatedUser user,
                                             @Valid @RequestBody PresenceRequest request) {
        return employees.changePresence(user, request.presence());
    }
}
