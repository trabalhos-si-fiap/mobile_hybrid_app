package com.edu.api.ticket.service;

import com.edu.api.employee.entity.Employee;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketEvent;
import com.edu.api.ticket.entity.TicketEventType;
import com.edu.api.ticket.entity.TicketStatus;
import com.edu.api.ticket.event.TicketActivity;
import com.edu.api.ticket.repository.TicketEventRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

import java.time.Clock;

/** Grava a trilha (ticket_events) e publica as atividades que geram notificação. */
@Component
public class TicketActivityRecorder {

    private final TicketEventRepository events;
    private final ApplicationEventPublisher publisher;
    private final Clock clock;

    public TicketActivityRecorder(TicketEventRepository events, ApplicationEventPublisher publisher, Clock clock) {
        this.events = events;
        this.publisher = publisher;
        this.clock = clock;
    }

    /** O estado de destino é o estado atual do ticket. */
    public void record(Ticket ticket, TicketEventType type, TicketStatus fromStatus, Employee employee, String detail) {
        String text = detail != null && detail.length() > 500 ? detail.substring(0, 500) : detail;
        events.save(new TicketEvent(ticket, type, fromStatus, ticket.getStatus(), employee, text, clock.instant()));
    }

    public void publish(Ticket ticket, TicketActivity.Kind kind) {
        publisher.publishEvent(new TicketActivity(ticket.getId(), kind));
    }
}
