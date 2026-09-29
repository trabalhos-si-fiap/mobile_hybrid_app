package com.edu.api.ticket.entity;

import com.edu.api.user.entity.AdminUser;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Getter
@Entity
@Table(name = "ticket_messages")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TicketMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "ticket_id", nullable = false)
    private Ticket ticket;

    @Enumerated(EnumType.STRING)
    @Column(name = "sender_type", nullable = false, length = 10)
    private SenderType senderType;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_user_id")
    private AdminUser senderUser;

    @Column(nullable = false, length = 2000)
    private String body;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public TicketMessage(Ticket ticket, SenderType senderType, AdminUser senderUser, String body, Instant now) {
        this.ticket = ticket;
        this.senderType = senderType;
        this.senderUser = senderUser;
        this.body = body;
        this.createdAt = now;
    }

    public static TicketMessage system(Ticket ticket, String body, Instant now) {
        return new TicketMessage(ticket, SenderType.SYSTEM, null, body, now);
    }
}
