package com.edu.api.notification.repository;

import com.edu.api.notification.entity.Notification;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @Query("select n from Notification n where n.recipient.id = :userId order by n.createdAt desc, n.id desc")
    List<Notification> findRecent(@Param("userId") Long userId, Pageable page);

    @Query("select n from Notification n where n.recipient.id = :userId and n.readAt is null"
            + " order by n.createdAt desc, n.id desc")
    List<Notification> findUnread(@Param("userId") Long userId, Pageable page);

    @Query("select n from Notification n where n.id = :id and n.recipient.id = :userId")
    Optional<Notification> findOwned(@Param("id") Long id, @Param("userId") Long userId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update Notification n set n.readAt = :now where n.recipient.id = :userId and n.readAt is null")
    int markAllRead(@Param("userId") Long userId, @Param("now") Instant now);
}
