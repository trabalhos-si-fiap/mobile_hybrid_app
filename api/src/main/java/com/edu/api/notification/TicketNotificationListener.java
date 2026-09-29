package com.edu.api.notification;

import com.edu.api.employee.entity.Skill;
import com.edu.api.employee.repository.EmployeeRepository;
import com.edu.api.notification.NotificationRules.Draft;
import com.edu.api.notification.entity.Notification;
import com.edu.api.notification.repository.NotificationRepository;
import com.edu.api.ticket.entity.Ticket;
import com.edu.api.ticket.event.TicketActivity;
import com.edu.api.ticket.repository.TicketRepository;
import com.edu.api.user.repository.AdminUserRepository;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

/**
 * Transforma atividades de ticket em notificações, na mesma transação da
 * ação. As atribuições feitas pelo PL/SQL já gravam as próprias notificações.
 */
@Component
public class TicketNotificationListener {

    private final TicketRepository tickets;
    private final EmployeeRepository employees;
    private final AdminUserRepository users;
    private final NotificationRepository notifications;
    private final Clock clock;

    public TicketNotificationListener(TicketRepository tickets, EmployeeRepository employees,
                                      AdminUserRepository users, NotificationRepository notifications, Clock clock) {
        this.tickets = tickets;
        this.employees = employees;
        this.users = users;
        this.notifications = notifications;
        this.clock = clock;
    }

    @EventListener
    public void on(TicketActivity activity) {
        Ticket ticket = tickets.findDetailedById(activity.ticketId()).orElseThrow();
        List<Draft> drafts = activity.kind() == TicketActivity.Kind.ENGINEERING_ALERT
                ? employees.findBySkillCode(Skill.DESENVOLVEDOR).stream()
                        .map(dev -> NotificationRules.engineeringAlert(dev.getUser().getId(), ticket.getId(),
                                ticket.getEngineeringAlertReason()))
                        .toList()
                : NotificationRules.forActivity(activity, ticket.getRequester().getId(), assigneeUserId(ticket));

        Instant now = clock.instant();
        for (Draft draft : drafts) {
            notifications.save(new Notification(users.getReferenceById(draft.recipientUserId()), ticket.getId(),
                    draft.type(), draft.title(), draft.body(), now));
        }
    }

    private static Long assigneeUserId(Ticket ticket) {
        return ticket.getAssignedEmployee() == null ? null : ticket.getAssignedEmployee().getUser().getId();
    }
}
