package com.edu.api.inventory.entity;

import com.edu.api.product.entity.Product;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Getter
@Entity
@Table(name = "inventories")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Inventory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false, unique = true)
    private Product product;

    @Column(nullable = false)
    private int quantity;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(
        mappedBy = "inventory",
        cascade = CascadeType.ALL
)
private final List<InventoryAdjustment> adjustments = new ArrayList<>();

    public Inventory(Product product, int quantity) {
        this.product = product;
        this.quantity = quantity;
        product.attachInventory(this);
    }

    public InventoryAdjustment adjustTo(int newQuantity, String reason) {

        if (newQuantity < 0) {
            throw new IllegalArgumentException(
                    "A quantidade do estoque não pode ser negativa"
            );
        }

        var adjustment = new InventoryAdjustment(
                this,
                quantity,
                newQuantity,
                reason
        );

        quantity = newQuantity;
        adjustments.add(adjustment);

        return adjustment;
    }   

    @PrePersist
    @PreUpdate
    void updateTimestamp() {
        updatedAt = Instant.now();
    }
}
