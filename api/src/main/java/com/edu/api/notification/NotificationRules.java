package com.edu.api.notification;

import com.edu.api.notification.entity.NotificationType;
import com.edu.api.ticket.event.TicketActivity;

import java.util.List;

/** Quem é notificado e com que texto, para cada atividade. Regra pura. */
public final class NotificationRules {

    public record Draft(Long recipientUserId, NotificationType type, String title, String body) {}

    private NotificationRules() {
    }

    public static List<Draft> forActivity(TicketActivity activity, Long requesterUserId, Long assigneeUserId) {
        long id = activity.ticketId();
        return switch (activity.kind()) {
            case ASSUMED -> List.of(new Draft(requesterUserId, NotificationType.TICKET_ASSUMIDO,
                    "Atendimento iniciado", "Seu ticket #" + id + " está em atendimento."));
            case USER_MESSAGE -> toAssignee(assigneeUserId, NotificationType.NOVA_MENSAGEM,
                    "Nova mensagem", "O usuário respondeu no ticket #" + id + ".");
            case EMPLOYEE_MESSAGE -> List.of(new Draft(requesterUserId, NotificationType.NOVA_MENSAGEM,
                    "Nova mensagem", "O atendente respondeu no ticket #" + id + "."));
            case RESOLVED -> List.of(new Draft(requesterUserId, NotificationType.TICKET_RESOLVIDO,
                    "Ticket resolvido", "Confirme a solução ou reabra o ticket #" + id + "."));
            case CLOSED -> toAssignee(assigneeUserId, NotificationType.TICKET_FECHADO,
                    "Ticket fechado", "O ticket #" + id + " foi fechado.");
            case REOPENED -> toAssignee(assigneeUserId, NotificationType.NOVA_MENSAGEM,
                    "Ticket reaberto", "O usuário reabriu o ticket #" + id + ".");
            case ENGINEERING_ALERT -> List.of();
        };
    }

    /** Alerta para um desenvolvedor; os destinatários vêm da skill DESENVOLVEDOR. */
    public static Draft engineeringAlert(Long recipientUserId, long ticketId, String reason) {
        String body = "Ticket #" + ticketId + ": " + reason;
        return new Draft(recipientUserId, NotificationType.ALERTA_ENGENHARIA, "Alerta de engenharia",
                body.length() > 500 ? body.substring(0, 500) : body);
    }

    private static List<Draft> toAssignee(Long assigneeUserId, NotificationType type, String title, String body) {
        return assigneeUserId == null ? List.of() : List.of(new Draft(assigneeUserId, type, title, body));
    }
}
