package com.edu.api.ticket.service;

import com.edu.api.employee.entity.Employee;
import com.edu.api.employee.entity.Skill;
import com.edu.api.employee.repository.EmployeeRepository;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.shared.exception.ForbiddenException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.repository.TicketRepository;
import com.edu.api.ticket.repository.TicketTypeConfigRepository;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** Carrega tickets respeitando a visibilidade; fora dela, responde 404. */
@Component
public class TicketAccessResolver {

    private final TicketRepository tickets;
    private final EmployeeRepository employees;
    private final TicketTypeConfigRepository configs;

    public TicketAccessResolver(TicketRepository tickets, EmployeeRepository employees,
                                TicketTypeConfigRepository configs) {
        this.tickets = tickets;
        this.employees = employees;
        this.configs = configs;
    }

    public Ticket visibleTicket(AuthenticatedUser user, long ticketId) {
        Ticket ticket = tickets.findDetailedById(ticketId).orElseThrow(() -> notFound(ticketId));
        Employee employee = user.isStaff() ? employees.findByUserId(user.id()).orElse(null) : null;
        if (!TicketAccess.canView(user, employee, ticket, segmentsOf(employee))) {
            throw notFound(ticketId);
        }
        return ticket;
    }

    public Ticket ownTicketForUpdate(AuthenticatedUser user, long ticketId) {
        Ticket ticket = tickets.findForUpdate(ticketId).orElseThrow(() -> notFound(ticketId));
        if (!ticket.isRequestedBy(user.id())) {
            throw notFound(ticketId);
        }
        return ticket;
    }

    public Ticket staffTicketForUpdate(AuthenticatedUser user, Employee employee, long ticketId) {
        Ticket ticket = tickets.findForUpdate(ticketId).orElseThrow(() -> notFound(ticketId));
        if (!TicketAccess.canView(user, employee, ticket, segmentsOf(employee))) {
            throw notFound(ticketId);
        }
        return ticket;
    }

    public Employee requireEmployee(AuthenticatedUser user) {
        return employees.findByUserId(user.id()).orElseThrow(() ->
                new ForbiddenException("Usuário " + user.email() + " não está cadastrado como atendente"));
    }

    public Set<Segment> segmentsOf(Employee employee) {
        if (employee == null || employee.getSkills().isEmpty()) {
            return Set.of();
        }
        List<Long> skillIds = employee.getSkills().stream().map(Skill::getId).toList();
        return configs.findSegmentCodesBySkillIds(skillIds).stream()
                .map(Segment::valueOf)
                .collect(Collectors.toSet());
    }

    private static NotFoundException notFound(long ticketId) {
        return new NotFoundException("Ticket " + ticketId + " não encontrado");
    }
}
