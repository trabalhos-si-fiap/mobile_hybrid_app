package com.edu.api.ticket.entity;

import com.edu.api.employee.entity.Employee;
import com.edu.api.shared.exception.ConflictException;
import com.edu.api.user.entity.AdminUser;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Duration;
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

    public boolean isRequestedBy(Long userId) {
        return requester.getId().equals(userId);
    }

    public boolean isAssignedTo(Employee employee) {
        return employee != null && employee.sameAs(assignedEmployee);
    }

    public void assume(Employee employee, boolean actingAsAdmin, Instant now) {
        requireStatus("assumir", TicketStatus.EM_FILA, TicketStatus.ESCALADO);
        if (assignedEmployee != null && !isAssignedTo(employee) && !actingAsAdmin) {
            throw new ConflictException("Ticket " + id + " está atribuído a outro atendente");
        }
        assignedEmployee = employee;
        status = TicketStatus.EM_ATENDIMENTO;
        if (assumedAt == null) {
            assumedAt = now;
        }
        updatedAt = now;
    }

    public void resolve(Employee employee, boolean actingAsAdmin, Instant now) {
        requireStatus("encerrar", TicketStatus.EM_ATENDIMENTO);
        requireOwner(employee, actingAsAdmin);
        status = TicketStatus.RESOLVIDO;
        resolvedAt = now;
        updatedAt = now;
    }

    public void confirm(Instant now) {
        close(now);
    }

    /** Fechamento pelo job após 72 h sem resposta do usuário. */
    public void autoClose(Instant now) {
        close(now);
    }

    public void reopen(int slaMinutes, Instant now) {
        requireStatus("reabrir", TicketStatus.RESOLVIDO);
        status = TicketStatus.EM_ATENDIMENTO;
        resolvedAt = null;
        slaStartedAt = now;
        slaDueAt = now.plus(Duration.ofMinutes(slaMinutes));
        updatedAt = now;
    }

    public void transferTo(Segment target, Employee employee, boolean actingAsAdmin, Instant now) {
        requireStatus("transferir", TicketStatus.EM_FILA, TicketStatus.EM_ATENDIMENTO, TicketStatus.ESCALADO);
        requireOwner(employee, actingAsAdmin);
        if (target == segment) {
            throw new ConflictException("Ticket " + id + " já está no segmento " + target);
        }
        segment = target;
        assignedEmployee = null;
        status = TicketStatus.EM_FILA;
        slaStartedAt = null;
        slaDueAt = null;
        updatedAt = now;
    }

    public void raiseEngineeringAlert(String reason, Employee employee, boolean actingAsAdmin, Instant now) {
        if (status == TicketStatus.FECHADO) {
            throw new ConflictException("Ticket " + id + " está fechado");
        }
        requireOwner(employee, actingAsAdmin);
        engineeringAlert = true;
        engineeringAlertReason = reason;
        updatedAt = now;
    }

    public void requireUserCanPost() {
        if (status == TicketStatus.FECHADO) {
            throw new ConflictException("Ticket " + id + " está fechado");
        }
    }

    public void requireStaffCanPost(Employee employee, boolean actingAsAdmin) {
        requireStatus("responder", TicketStatus.EM_ATENDIMENTO);
        requireOwner(employee, actingAsAdmin);
    }

    /** Devolve à fila um ticket ainda não assumido (atendente saiu de ONLINE). */
    public void returnToQueue(Instant now) {
        requireStatus("devolver à fila", TicketStatus.EM_FILA);
        assignedEmployee = null;
        updatedAt = now;
    }

    public void touch(Instant now) {
        updatedAt = now;
    }

    private void close(Instant now) {
        requireStatus("fechar", TicketStatus.RESOLVIDO);
        status = TicketStatus.FECHADO;
        closedAt = now;
        updatedAt = now;
    }

    private void requireStatus(String action, TicketStatus... allowed) {
        for (TicketStatus candidate : allowed) {
            if (status == candidate) {
                return;
            }
        }
        throw new ConflictException("Não é possível " + action + " o ticket " + id + " no estado " + status);
    }

    private void requireOwner(Employee employee, boolean actingAsAdmin) {
        if (!actingAsAdmin && !isAssignedTo(employee)) {
            throw new ConflictException("Ticket " + id + " não está atribuído a você");
        }
    }
}
