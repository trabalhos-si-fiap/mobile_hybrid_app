package com.edu.api.ticket.dto;

import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketQueue;

public record SegmentResponse(Segment segment, String label, TicketQueue queue, String skill, int slaMinutes) {}
