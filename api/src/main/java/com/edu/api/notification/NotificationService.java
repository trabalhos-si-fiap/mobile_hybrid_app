package com.edu.api.notification;

import com.edu.api.notification.dto.NotificationResponse;
import com.edu.api.notification.entity.Notification;
import com.edu.api.notification.repository.NotificationRepository;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.shared.exception.NotFoundException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.util.List;

@Service
public class NotificationService {

    private static final Pageable LATEST = PageRequest.of(0, 50);

    private final NotificationRepository notifications;
    private final Clock clock;

    public NotificationService(NotificationRepository notifications, Clock clock) {
        this.notifications = notifications;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> list(AuthenticatedUser user, boolean unreadOnly) {
        List<Notification> found = unreadOnly
                ? notifications.findUnread(user.id(), LATEST)
                : notifications.findRecent(user.id(), LATEST);
        return found.stream().map(NotificationResponse::of).toList();
    }

    @Transactional
    public void markRead(AuthenticatedUser user, long notificationId) {
        notifications.findOwned(notificationId, user.id())
                .orElseThrow(() -> new NotFoundException("Notificação " + notificationId + " não encontrada"))
                .markRead(clock.instant());
    }

    @Transactional
    public int markAllRead(AuthenticatedUser user) {
        return notifications.markAllRead(user.id(), clock.instant());
    }
}
