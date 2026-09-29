package com.edu.api.ticket.entity;

import com.edu.api.employee.entity.Employee;
import com.edu.api.user.entity.AdminUser;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Getter
@Entity
@Table(name = "tickets")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Ticket {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AdminUser requester;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private Segment segment;

    @Column(nullable = false, length = 2000)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TicketChannel channel;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TicketStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private TicketPriority priority;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_employee_id")
    private Employee assignedEmployee;

    @Column(name = "sla_started_at")
    private Instant slaStartedAt;

    @Column(name = "sla_due_at")
    private Instant slaDueAt;

    @Column(name = "engineering_alert", nullable = false)
    private boolean engineeringAlert;

    @Column(name = "engineering_alert_reason", length = 500)
    private String engineeringAlertReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "assumed_at")
    private Instant assumedAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    @Column(name = "closed_at")
    private Instant closedAt;

    public static Ticket open(AdminUser requester, Segment segment, String description,
                              TicketChannel channel, Instant now) {
        Ticket ticket = new Ticket();
        ticket.requester = requester;
        ticket.segment = segment;
        ticket.description = description;
        ticket.channel = channel;
        ticket.status = TicketStatus.ABERTO;
        ticket.priority = TicketPriority.NORMAL;
        ticket.createdAt = now;
        ticket.updatedAt = now;
        return ticket;
    }
}
