package com.edu.api.notification;

import com.edu.api.notification.dto.NotificationResponse;
import com.edu.api.notification.entity.NotificationType;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.support.FullStackIntegration;
import com.edu.api.ticket.service.TicketService;
import com.edu.api.ticket.service.TicketStaffService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class NotificationsIT extends FullStackIntegration {

    @Autowired
    private TicketStaffService staff;

    @Autowired
    private TicketService tickets;

    @Autowired
    private NotificationService notifications;

    @Test
    void assumingNotifiesTheRequester() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").assignedTo(agent).insert();

        staff.assume(login(fx.userOf(agent), "EMPLOYEE"), ticket);

        assertThat(notifications.list(login(requester, "USER"), true))
                .extracting(NotificationResponse::type)
                .containsExactly(NotificationType.TICKET_ASSUMIDO);
    }

    @Test
    void agentMessageNotifiesTheRequester() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").assignedTo(agent).insert();

        tickets.postMessage(login(fx.userOf(agent), "EMPLOYEE"), ticket, "Pode reinstalar o app?", null);

        assertThat(notifications.list(login(requester, "USER"), true))
                .extracting(NotificationResponse::type, NotificationResponse::ticketId)
                .containsExactly(org.assertj.core.groups.Tuple.tuple(NotificationType.NOVA_MENSAGEM, ticket));
    }

    @Test
    void engineeringAlertNotifiesEveryDeveloper() {
        long requester = fx.user("USER");
        long owner = fx.employee("ONLINE", "GESTAO_ENTREGAS");
        long onlineDev = fx.employee("ONLINE", "DESENVOLVEDOR");
        long offlineDev = fx.employee("OFFLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_ATENDIMENTO").assignedTo(owner).insert();

        staff.engineeringAlert(login(fx.userOf(owner), "EMPLOYEE"), ticket, "Cobrança duplicada no checkout");

        String sql = "SELECT COUNT(*) FROM notifications WHERE ticket_id = ? AND type = 'ALERTA_ENGENHARIA'"
                + " AND recipient_user_id = ?";
        assertThat(fx.count(sql, ticket, fx.userOf(onlineDev))).isEqualTo(1);
        assertThat(fx.count(sql, ticket, fx.userOf(offlineDev))).isEqualTo(1);
        assertThat(fx.count(sql, ticket, fx.userOf(owner))).isZero();
    }

    @Test
    void listsAndMarksNotificationsAsRead() {
        long user = fx.user("USER");
        long first = fx.notification(user);
        fx.notification(user);

        notifications.markRead(login(user, "USER"), first);
        assertThat(notifications.list(login(user, "USER"), true)).hasSize(1);

        assertThat(notifications.markAllRead(login(user, "USER"))).isEqualTo(1);
        assertThat(notifications.list(login(user, "USER"), true)).isEmpty();
        assertThat(notifications.list(login(user, "USER"), false)).hasSize(2).allMatch(NotificationResponse::read);
    }

    @Test
    void cannotReadSomeoneElsesNotification() {
        long owner = fx.user("USER");
        long stranger = fx.user("USER");
        long notification = fx.notification(owner);

        assertThatThrownBy(() -> notifications.markRead(login(stranger, "USER"), notification))
                .isInstanceOf(NotFoundException.class);
    }
}
