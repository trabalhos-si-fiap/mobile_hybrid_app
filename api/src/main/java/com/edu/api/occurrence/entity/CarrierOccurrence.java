package com.edu.api.occurrence.entity;

import com.edu.api.carrier.entity.Carrier;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Getter
@Entity
@Table(name = "carrier_occurrences")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CarrierOccurrence {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "carrier_id", nullable = false)
    private Carrier carrier;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private OccurrenceType type;

    @Column(nullable = false, length = 500)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OccurrenceStatus status = OccurrenceStatus.OPEN;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    public CarrierOccurrence(Carrier carrier, OccurrenceType type, String description) {
        this.carrier = carrier;
        this.type = type;
        this.description = description;
    }

    public void updateStatus(OccurrenceStatus status) {
        this.status = status;
        this.resolvedAt = status == OccurrenceStatus.RESOLVED ? Instant.now() : null;
    }

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
    }
}
