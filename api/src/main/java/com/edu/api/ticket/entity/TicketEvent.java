package com.edu.api.ticket.entity;

import com.edu.api.employee.entity.Employee;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

/** Trilha de auditoria do ticket; gravada pelo Java e pelas procedures. */
@Getter
@Entity
@Table(name = "ticket_events")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TicketEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "ticket_id", nullable = false)
    private Ticket ticket;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TicketEventType type;

    @Enumerated(EnumType.STRING)
    @Column(name = "from_status", length = 20)
    private TicketStatus fromStatus;

    @Enumerated(EnumType.STRING)
    @Column(name = "to_status", length = 20)
    private TicketStatus toStatus;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id")
    private Employee employee;

    @Column(length = 500)
    private String detail;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public TicketEvent(Ticket ticket, TicketEventType type, TicketStatus fromStatus, TicketStatus toStatus,
                       Employee employee, String detail, Instant now) {
        this.ticket = ticket;
        this.type = type;
        this.fromStatus = fromStatus;
        this.toStatus = toStatus;
        this.employee = employee;
        this.detail = detail;
        this.createdAt = now;
    }
}
