package com.edu.api.ticket.service;

import com.edu.api.employee.entity.Employee;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.Ticket;

import java.util.Set;

/** Quem pode ver um ticket. Regra pura, sem acesso a banco. */
public final class TicketAccess {

    private TicketAccess() {
    }

    /**
     * @param employee         o cadastro de atendente do usuário, ou nulo
     * @param employeeSegments segmentos cujas skills o atendente tem
     */
    public static boolean canView(AuthenticatedUser user, Employee employee, Ticket ticket,
                                  Set<Segment> employeeSegments) {
        if (ticket.isRequestedBy(user.id())) {
            return true;
        }
        if (!user.isStaff()) {
            return false;
        }
        if (user.isAdmin()) {
            return true;
        }
        return employee != null
                && (ticket.isAssignedTo(employee) || employeeSegments.contains(ticket.getSegment()));
    }
}
