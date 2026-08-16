package com.edu.api.inventory.service;

import com.edu.api.inventory.dto.AdjustInventoryRequest;
import com.edu.api.inventory.dto.InventoryResponse;
import com.edu.api.inventory.entity.Inventory;
import com.edu.api.inventory.entity.InventoryAdjustment;
import com.edu.api.inventory.repository.InventoryRepository;
import com.edu.api.product.entity.Product;
import com.edu.api.product.repository.ProductRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class InventoryService {

    private final InventoryRepository inventoryRepository;

    public InventoryService(
            InventoryRepository inventoryRepository,
            ProductRepository productRepository
    ) {
        this.inventoryRepository = inventoryRepository;
    }

    @Transactional(readOnly = true)
    public Page<InventoryResponse> findAll(
            String search,
            boolean lowStock,
            Pageable pageable
    ) {

        Page<Inventory> inventories;

        if (lowStock) {
            inventories = inventoryRepository.findBelowMinimum(pageable);
        } else if (search != null && !search.isBlank()) {
            inventories = inventoryRepository
                    .findByProductNameContainingIgnoreCaseOrProductSkuContainingIgnoreCase(
                            search,
                            search,
                            pageable
                    );
        } else {
            inventories = inventoryRepository.findAll(pageable);
        }

        return inventories.map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public InventoryResponse findByProductId(Long productId) {

        Inventory inventory = inventoryRepository.findByProductId(productId)
                .orElseThrow(() ->
                        new RuntimeException("Estoque do produto não encontrado")
                );

        return toResponse(inventory);
    }

    @Transactional
    public InventoryResponse adjust(
            Long productId,
            AdjustInventoryRequest request
    ) {

        Inventory inventory = inventoryRepository.findByProductId(productId)
                .orElseThrow(() ->
                        new RuntimeException("Estoque do produto não encontrado")
                );

        if (request.quantity() < 0) {
            throw new RuntimeException(
                    "A quantidade do estoque não pode ser negativa"
            );
        }

        InventoryAdjustment adjustment = inventory.adjustTo(
                request.quantity(),
                request.reason()
        );

        inventoryRepository.save(inventory);

        return toResponse(inventory);
    }

    private InventoryResponse toResponse(Inventory inventory) {

        Product product = inventory.getProduct();

        return new InventoryResponse(
                product.getId(),
                product.getName(),
                product.getSku(),
                inventory.getQuantity(),
                product.getMinimumStock(),
                getStatus(inventory)
        );
    }

    private String getStatus(Inventory inventory) {

        int quantity = inventory.getQuantity();
        int minimumStock = inventory.getProduct().getMinimumStock();

        if (quantity == 0) {
            return "OUT_OF_STOCK";
        }

        if (quantity < minimumStock) {
            return "LOW_STOCK";
        }

        return "NORMAL";
    }
}