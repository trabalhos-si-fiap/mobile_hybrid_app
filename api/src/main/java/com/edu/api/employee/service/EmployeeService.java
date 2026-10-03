package com.edu.api.employee.service;

import com.edu.api.employee.dto.EmployeeMeResponse;
import com.edu.api.employee.entity.Employee;
import com.edu.api.employee.entity.Presence;
import com.edu.api.employee.entity.Skill;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.entity.TicketStatus;
import com.edu.api.ticket.plsql.TicketProcedures;
import com.edu.api.ticket.repository.TicketRepository;
import com.edu.api.ticket.service.TicketAccessResolver;
import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Set;

/** Presença do atendente; mudar de presença redistribui a fila. */
@Service
public class EmployeeService {

    private static final List<TicketStatus> WAITING = List.of(TicketStatus.EM_FILA, TicketStatus.ESCALADO);

    private final TicketAccessResolver access;
    private final TicketRepository tickets;
    private final TicketProcedures procedures;
    private final EntityManager entityManager;
    private final Clock clock;

    public EmployeeService(TicketAccessResolver access, TicketRepository tickets, TicketProcedures procedures,
                           EntityManager entityManager, Clock clock) {
        this.access = access;
        this.tickets = tickets;
        this.procedures = procedures;
        this.entityManager = entityManager;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public EmployeeMeResponse me(AuthenticatedUser user) {
        return view(access.requireEmployee(user));
    }

    @Transactional
    public EmployeeMeResponse changePresence(AuthenticatedUser user, Presence presence) {
        Employee me = access.requireEmployee(user);
        Instant now = clock.instant();
        me.changePresence(presence, now);

        List<Long> toRoute;
        if (presence == Presence.ONLINE) {
            Set<Segment> segments = access.segmentsOf(me);
            toRoute = segments.isEmpty() ? List.of() : tickets.findUnassignedIds(WAITING, segments);
        } else {
            List<Ticket> notAssumed = tickets.findByStatusAndAssignee(TicketStatus.EM_FILA, me.getId());
            notAssumed.forEach(ticket -> ticket.returnToQueue(now));
            toRoute = notAssumed.stream().map(Ticket::getId).toList();
        }

        entityManager.flush();
        procedures.routeEach(toRoute);
        return view(me);
    }

    private static EmployeeMeResponse view(Employee employee) {
        List<String> skills = employee.getSkills().stream().map(Skill::getCode).sorted().toList();
        return new EmployeeMeResponse(employee.getId(), employee.getUser().getName(), employee.getPresence(),
                employee.getPresenceChangedAt(), skills);
    }
}
