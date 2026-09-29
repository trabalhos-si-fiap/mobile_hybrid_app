package com.edu.api.ticket.controller;

import com.edu.api.security.AuthenticatedUser;
import com.edu.api.ticket.dto.*;
import com.edu.api.ticket.entity.TicketStatus;
import com.edu.api.ticket.service.TicketStaffService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Endpoints do console do atendente (EMPLOYEE/ADMIN, ver SecurityConfig). */
@RestController
@RequestMapping("/tickets")
public class TicketStaffController {

    private final TicketStaffService staff;

    public TicketStaffController(TicketStaffService staff) {
        this.staff = staff;
    }

    @GetMapping("/queue")
    public List<TicketSummaryResponse> queue(@AuthenticationPrincipal AuthenticatedUser user,
                                             @RequestParam(defaultValue = "mine") String scope,
                                             @RequestParam(required = false) TicketStatus status) {
        return staff.queue(user, QueueScope.parse(scope), status);
    }

    @GetMapping("/{ticketId}/events")
    public List<TicketEventResponse> events(@AuthenticationPrincipal AuthenticatedUser user,
                                            @PathVariable long ticketId) {
        return staff.events(user, ticketId);
    }

    @PostMapping("/{ticketId}/assume")
    public TicketDetailResponse assume(@AuthenticationPrincipal AuthenticatedUser user,
                                       @PathVariable long ticketId) {
        return staff.assume(user, ticketId);
    }

    @PostMapping("/{ticketId}/resolve")
    public TicketDetailResponse resolve(@AuthenticationPrincipal AuthenticatedUser user,
                                        @PathVariable long ticketId) {
        return staff.resolve(user, ticketId);
    }

    @PostMapping("/{ticketId}/transfer")
    public TicketDetailResponse transfer(@AuthenticationPrincipal AuthenticatedUser user,
                                         @PathVariable long ticketId,
                                         @Valid @RequestBody TransferRequest request) {
        return staff.transfer(user, ticketId, request.segment());
    }

    @PostMapping("/{ticketId}/engineering-alert")
    public TicketDetailResponse engineeringAlert(@AuthenticationPrincipal AuthenticatedUser user,
                                                 @PathVariable long ticketId,
                                                 @Valid @RequestBody EngineeringAlertRequest request) {
        return staff.engineeringAlert(user, ticketId, request.reason());
    }
}
