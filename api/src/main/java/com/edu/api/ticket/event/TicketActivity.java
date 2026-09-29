package com.edu.api.ticket.event;

/** Evento Spring publicado a cada ação relevante; gera notificações. */
public record TicketActivity(Long ticketId, Kind kind) {

    public enum Kind {
        ASSUMED,
        USER_MESSAGE,
        EMPLOYEE_MESSAGE,
        RESOLVED,
        CLOSED,
        REOPENED,
        ENGINEERING_ALERT
    }
}
