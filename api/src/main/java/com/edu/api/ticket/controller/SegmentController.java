package com.edu.api.ticket.controller;

import com.edu.api.ticket.dto.SegmentResponse;
import com.edu.api.ticket.service.TicketService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class SegmentController {

    private final TicketService tickets;

    public SegmentController(TicketService tickets) {
        this.tickets = tickets;
    }

    @GetMapping("/segments")
    public List<SegmentResponse> segments() {
        return tickets.segments();
    }
}
