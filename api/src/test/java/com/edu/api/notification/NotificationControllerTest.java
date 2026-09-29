package com.edu.api.notification;

import com.edu.api.notification.dto.NotificationResponse;
import com.edu.api.notification.entity.NotificationType;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.support.ControllerSliceTest;
import com.edu.api.support.WithAuthenticatedUser;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ControllerSliceTest(NotificationController.class)
@WithAuthenticatedUser
class NotificationControllerTest {

    private static final AuthenticatedUser USER = new AuthenticatedUser(1L, "usuario@edu.com", "USER");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private NotificationService notifications;

    @Test
    void listsOnlyUnreadWhenAsked() throws Exception {
        when(notifications.list(USER, true)).thenReturn(List.of(new NotificationResponse(5L, 7L,
                NotificationType.TICKET_ASSUMIDO, "Atendimento iniciado", "Seu ticket #7 está em atendimento.",
                false, Instant.parse("2030-01-01T12:00:00Z"))));

        mockMvc.perform(get("/notifications").param("unreadOnly", "true"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].type").value("TICKET_ASSUMIDO"))
                .andExpect(jsonPath("$[0].read").value(false));
    }

    @Test
    void marksOneAsRead() throws Exception {
        mockMvc.perform(post("/notifications/5/read")).andExpect(status().isNoContent());

        verify(notifications).markRead(USER, 5L);
    }

    @Test
    void marksAllAsRead() throws Exception {
        mockMvc.perform(post("/notifications/read-all")).andExpect(status().isNoContent());

        verify(notifications).markAllRead(USER);
    }
}
