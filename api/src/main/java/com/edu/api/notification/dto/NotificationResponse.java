package com.edu.api.notification.dto;

import com.edu.api.notification.entity.Notification;
import com.edu.api.notification.entity.NotificationType;

import java.time.Instant;

public record NotificationResponse(Long id, Long ticketId, NotificationType type, String title, String body,
                                   boolean read, Instant createdAt) {

    public static NotificationResponse of(Notification notification) {
        return new NotificationResponse(notification.getId(), notification.getTicketId(), notification.getType(),
                notification.getTitle(), notification.getBody(), notification.isRead(), notification.getCreatedAt());
    }
}
