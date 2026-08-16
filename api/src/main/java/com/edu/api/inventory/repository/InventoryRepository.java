package com.edu.api.inventory.repository;

import com.edu.api.inventory.entity.Inventory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;

public interface InventoryRepository extends JpaRepository<Inventory, Long> {

    Optional<Inventory> findByProductId(Long productId);

    Page<Inventory> findByProductNameContainingIgnoreCaseOrProductSkuContainingIgnoreCase(
            String name,
            String sku,
            Pageable pageable
    );

    @Query("""
        SELECT i
        FROM Inventory i
        JOIN i.product p
        WHERE i.quantity < p.minimumStock
        """)
    Page<Inventory> findBelowMinimum(Pageable pageable);
}