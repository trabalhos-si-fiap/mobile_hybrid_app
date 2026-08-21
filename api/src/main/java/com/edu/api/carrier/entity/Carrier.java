package com.edu.api.carrier.entity;

import com.edu.api.occurrence.entity.CarrierOccurrence;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Getter
@Entity
@Table(name = "carriers")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Carrier {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false, length = 150)
    private String location;

    @Column(nullable = false, length = 254)
    private String email;

    @Column(name = "average_delivery_days", nullable = false)
    private int averageDeliveryDays;

    @Column(nullable = false, precision = 2, scale = 1)
    private BigDecimal rating;

    @Column(name = "sla_percentage", nullable = false, precision = 5, scale = 2)
    private BigDecimal slaPercentage;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CarrierStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "carrier")
    private final List<CarrierOccurrence> occurrences = new ArrayList<>();

    public Carrier(String name, String location, String email, int averageDeliveryDays,
                   BigDecimal rating, BigDecimal slaPercentage, CarrierStatus status) {
        update(name, location, email, averageDeliveryDays, rating, slaPercentage, status);
    }

    public void update(String name, String location, String email, int averageDeliveryDays,
                       BigDecimal rating, BigDecimal slaPercentage, CarrierStatus status) {
        this.name = name;
        this.location = location;
        this.email = email;
        this.averageDeliveryDays = averageDeliveryDays;
        this.rating = rating;
        this.slaPercentage = slaPercentage;
        this.status = status;
    }

    public void updateStatus(CarrierStatus status) {
        this.status = status;
    }

    @PrePersist
    void onCreate() {
        var now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
