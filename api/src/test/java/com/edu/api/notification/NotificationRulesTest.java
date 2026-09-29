package com.edu.api.notification;

import com.edu.api.notification.NotificationRules.Draft;
import com.edu.api.notification.entity.NotificationType;
import com.edu.api.ticket.event.TicketActivity;
import com.edu.api.ticket.event.TicketActivity.Kind;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class NotificationRulesTest {

    private static final long REQUESTER = 1L;
    private static final long ASSIGNEE = 2L;

    private static List<Draft> drafts(Kind kind, Long assignee) {
        return NotificationRules.forActivity(new TicketActivity(7L, kind), REQUESTER, assignee);
    }

    @Test
    void assumingNotifiesTheRequester() {
        assertThat(drafts(Kind.ASSUMED, ASSIGNEE)).singleElement()
                .satisfies(d -> {
                    assertThat(d.recipientUserId()).isEqualTo(REQUESTER);
                    assertThat(d.type()).isEqualTo(NotificationType.TICKET_ASSUMIDO);
                    assertThat(d.body()).contains("#7");
                });
    }

    @Test
    void userMessageNotifiesTheAssignee() {
        assertThat(drafts(Kind.USER_MESSAGE, ASSIGNEE)).singleElement()
                .extracting(Draft::recipientUserId, Draft::type)
                .containsExactly(ASSIGNEE, NotificationType.NOVA_MENSAGEM);
    }

    @Test
    void userMessageWithoutAssigneeNotifiesNobody() {
        assertThat(drafts(Kind.USER_MESSAGE, null)).isEmpty();
    }

    @Test
    void agentMessageNotifiesTheRequester() {
        assertThat(drafts(Kind.EMPLOYEE_MESSAGE, ASSIGNEE)).singleElement()
                .extracting(Draft::recipientUserId, Draft::type)
                .containsExactly(REQUESTER, NotificationType.NOVA_MENSAGEM);
    }

    @Test
    void resolvingAsksTheRequesterToConfirm() {
        assertThat(drafts(Kind.RESOLVED, ASSIGNEE)).singleElement()
                .extracting(Draft::recipientUserId, Draft::type)
                .containsExactly(REQUESTER, NotificationType.TICKET_RESOLVIDO);
    }

    @Test
    void closingNotifiesTheAssignee() {
        assertThat(drafts(Kind.CLOSED, ASSIGNEE)).singleElement()
                .extracting(Draft::recipientUserId, Draft::type)
                .containsExactly(ASSIGNEE, NotificationType.TICKET_FECHADO);
    }

    @Test
    void reopeningNotifiesTheAssignee() {
        assertThat(drafts(Kind.REOPENED, ASSIGNEE)).singleElement()
                .extracting(Draft::recipientUserId, Draft::type)
                .containsExactly(ASSIGNEE, NotificationType.NOVA_MENSAGEM);
    }
}
