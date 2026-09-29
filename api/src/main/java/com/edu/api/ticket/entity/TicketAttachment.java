package com.edu.api.ticket.entity;

import com.edu.api.user.entity.AdminUser;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Getter
@Entity
@Table(name = "ticket_attachments")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TicketAttachment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "ticket_id", nullable = false)
    private Ticket ticket;

    /** Nulo quando o anexo veio na abertura do ticket. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "message_id")
    private TicketMessage message;

    @Column(name = "object_key", nullable = false, unique = true, length = 200)
    private String objectKey;

    @Column(name = "file_name", nullable = false, length = 255)
    private String fileName;

    @Column(name = "content_type", nullable = false, length = 100)
    private String contentType;

    @Column(name = "size_bytes", nullable = false)
    private long sizeBytes;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "uploaded_by", nullable = false)
    private AdminUser uploadedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public TicketAttachment(Ticket ticket, TicketMessage message, String objectKey, String fileName,
                            String contentType, long sizeBytes, AdminUser uploadedBy, Instant now) {
        this.ticket = ticket;
        this.message = message;
        this.objectKey = objectKey;
        this.fileName = fileName;
        this.contentType = contentType;
        this.sizeBytes = sizeBytes;
        this.uploadedBy = uploadedBy;
        this.createdAt = now;
    }
}
