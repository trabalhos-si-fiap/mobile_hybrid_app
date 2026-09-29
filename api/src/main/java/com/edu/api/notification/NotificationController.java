package com.edu.api.notification;

import com.edu.api.notification.dto.NotificationResponse;
import com.edu.api.security.AuthenticatedUser;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/notifications")
public class NotificationController {

    private final NotificationService notifications;

    public NotificationController(NotificationService notifications) {
        this.notifications = notifications;
    }

    @GetMapping
    public List<NotificationResponse> list(@AuthenticationPrincipal AuthenticatedUser user,
                                           @RequestParam(defaultValue = "false") boolean unreadOnly) {
        return notifications.list(user, unreadOnly);
    }

    @PostMapping("/{notificationId}/read")
    public ResponseEntity<Void> markRead(@AuthenticationPrincipal AuthenticatedUser user,
                                         @PathVariable long notificationId) {
        notifications.markRead(user, notificationId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/read-all")
    public ResponseEntity<Void> markAllRead(@AuthenticationPrincipal AuthenticatedUser user) {
        notifications.markAllRead(user);
        return ResponseEntity.noContent().build();
    }
}
