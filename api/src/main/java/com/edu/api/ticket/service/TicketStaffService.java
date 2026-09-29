package com.edu.api.ticket.service;

import com.edu.api.employee.entity.Employee;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.shared.exception.ForbiddenException;
import com.edu.api.ticket.dto.QueueScope;
import com.edu.api.ticket.dto.TicketDetailResponse;
import com.edu.api.ticket.dto.TicketEventResponse;
import com.edu.api.ticket.dto.TicketSummaryResponse;
import com.edu.api.ticket.entity.*;
import com.edu.api.ticket.event.TicketActivity;
import com.edu.api.ticket.plsql.TicketProcedures;
import com.edu.api.ticket.repository.TicketEventRepository;
import com.edu.api.ticket.repository.TicketRepository;
import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.util.Comparator;
import java.util.List;
import java.util.Set;

/** Lado do atendente: fila, ações rápidas e linha do tempo. */
@Service
public class TicketStaffService {

    static final List<TicketStatus> ACTIVE = List.of(
            TicketStatus.EM_FILA, TicketStatus.EM_ATENDIMENTO, TicketStatus.ESCALADO);
    static final List<TicketStatus> MINE = List.of(
            TicketStatus.EM_FILA, TicketStatus.EM_ATENDIMENTO, TicketStatus.ESCALADO, TicketStatus.RESOLVIDO);
    static final List<TicketStatus> NOT_CLOSED = List.of(
            TicketStatus.ABERTO, TicketStatus.EM_FILA, TicketStatus.EM_ATENDIMENTO,
            TicketStatus.ESCALADO, TicketStatus.RESOLVIDO);

    /** Prioridade mais alta primeiro, depois o prazo mais próximo. */
    static final Comparator<Ticket> QUEUE_ORDER = Comparator.comparing(Ticket::getPriority).reversed()
            .thenComparing(Ticket::getSlaDueAt, Comparator.nullsLast(Comparator.naturalOrder()))
            .thenComparing(Ticket::getCreatedAt);

    private final TicketRepository tickets;
    private final TicketEventRepository events;
    private final TicketAccessResolver access;
    private final TicketProcedures procedures;
    private final TicketActivityRecorder activity;
    private final TicketViews views;
    private final EntityManager entityManager;
    private final Clock clock;

    public TicketStaffService(TicketRepository tickets, TicketEventRepository events, TicketAccessResolver access,
                              TicketProcedures procedures, TicketActivityRecorder activity, TicketViews views,
                              EntityManager entityManager, Clock clock) {
        this.tickets = tickets;
        this.events = events;
        this.access = access;
        this.procedures = procedures;
        this.activity = activity;
        this.views = views;
        this.entityManager = entityManager;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<TicketSummaryResponse> queue(AuthenticatedUser user, QueueScope scope, TicketStatus status) {
        List<Ticket> found = switch (scope) {
            case MINE -> {
                List<TicketStatus> statuses = filter(MINE, status);
                yield statuses.isEmpty() ? List.of()
                        : tickets.findAssignedTo(access.requireEmployee(user).getId(), statuses);
            }
            case SKILLS -> {
                Set<Segment> segments = access.segmentsOf(access.requireEmployee(user));
                List<TicketStatus> statuses = filter(ACTIVE, status);
                yield segments.isEmpty() || statuses.isEmpty() ? List.of()
                        : tickets.findBySegmentsAndStatuses(segments, statuses);
            }
            case ALL -> {
                if (!user.isAdmin()) {
                    throw new ForbiddenException("Somente ADMIN pode ver todos os tickets");
                }
                List<TicketStatus> statuses = filter(NOT_CLOSED, status);
                yield statuses.isEmpty() ? List.of() : tickets.findByStatuses(statuses);
            }
        };
        return views.summaries(found.stream().sorted(QUEUE_ORDER).toList());
    }

    @Transactional(readOnly = true)
    public List<TicketEventResponse> events(AuthenticatedUser user, long ticketId) {
        Ticket ticket = access.visibleTicket(user, ticketId);
        return views.events(events.findByTicket(ticket.getId()));
    }

    @Transactional
    public TicketDetailResponse assume(AuthenticatedUser user, long ticketId) {
        Employee me = access.requireEmployee(user);
        Ticket ticket = access.staffTicketForUpdate(user, me, ticketId);
        TicketStatus from = ticket.getStatus();

        ticket.assume(me, user.isAdmin(), clock.instant());
        activity.record(ticket, TicketEventType.ASSUMIDO, from, me, null);
        activity.publish(ticket, TicketActivity.Kind.ASSUMED);
        return views.detail(ticket);
    }

    @Transactional
    public TicketDetailResponse resolve(AuthenticatedUser user, long ticketId) {
        Employee me = access.requireEmployee(user);
        Ticket ticket = access.staffTicketForUpdate(user, me, ticketId);
        TicketStatus from = ticket.getStatus();

        ticket.resolve(me, user.isAdmin(), clock.instant());
        activity.record(ticket, TicketEventType.RESOLVIDO, from, me, null);
        activity.publish(ticket, TicketActivity.Kind.RESOLVED);
        return views.detail(ticket);
    }

    @Transactional
    public TicketDetailResponse transfer(AuthenticatedUser user, long ticketId, Segment target) {
        Employee me = access.requireEmployee(user);
        Ticket ticket = access.staffTicketForUpdate(user, me, ticketId);
        TicketStatus from = ticket.getStatus();
        Segment previous = ticket.getSegment();

        ticket.transferTo(target, me, user.isAdmin(), clock.instant());
        activity.record(ticket, TicketEventType.TRANSFERIDO, from, me, previous + " -> " + target);

        entityManager.flush();
        procedures.route(ticket.getId());
        entityManager.refresh(ticket);
        return views.detail(ticket);
    }

    @Transactional
    public TicketDetailResponse engineeringAlert(AuthenticatedUser user, long ticketId, String reason) {
        Employee me = access.requireEmployee(user);
        Ticket ticket = access.staffTicketForUpdate(user, me, ticketId);
        TicketStatus from = ticket.getStatus();
        String text = reason.strip();

        ticket.raiseEngineeringAlert(text, me, user.isAdmin(), clock.instant());
        activity.record(ticket, TicketEventType.ALERTA_ENGENHARIA, from, me, text);
        activity.publish(ticket, TicketActivity.Kind.ENGINEERING_ALERT);
        return views.detail(ticket);
    }

    private static List<TicketStatus> filter(List<TicketStatus> allowed, TicketStatus status) {
        if (status == null) {
            return allowed;
        }
        return allowed.contains(status) ? List.of(status) : List.of();
    }
}
