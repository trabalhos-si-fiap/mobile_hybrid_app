package com.edu.api.product.service;

import com.edu.api.inventory.entity.Inventory;
import com.edu.api.inventory.repository.InventoryRepository;
import com.edu.api.product.dto.CreateProductRequest;
import com.edu.api.product.dto.ProductResponse;
import com.edu.api.product.dto.UpdateProductRequest;
import com.edu.api.product.entity.Product;
import com.edu.api.product.repository.ProductRepository;
import com.edu.api.shared.exception.NotFoundException;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ProductService {

    private final ProductRepository productRepository;
    private final InventoryRepository inventoryRepository;

    public ProductService(
            ProductRepository productRepository,
            InventoryRepository inventoryRepository
    ) {
        this.productRepository = productRepository;
        this.inventoryRepository = inventoryRepository;
    }

    @Transactional
    public ProductResponse create(CreateProductRequest request) {

        Product product = new Product(
                request.name(),
                request.description(),
                request.price(),
                request.minimumStock()
        );

        productRepository.save(product);

        Inventory inventory = new Inventory(product, 0);

        inventoryRepository.save(inventory);

        return toResponse(product);
    }

    @Transactional(readOnly = true)
    public List<ProductResponse> findAll() {

        return productRepository.findAll()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public ProductResponse findById(Long id) {

        Product product = productRepository.findById(id)
                .orElseThrow(() ->
                        new NotFoundException("Produto não encontrado")
                );

        return toResponse(product);
    }

    @Transactional
    public ProductResponse update(
            Long id,
            UpdateProductRequest request
    ) {

        Product product = productRepository.findById(id)
                .orElseThrow(() ->
                        new NotFoundException("Produto não encontrado")
                );

        product.update(
                request.name(),
                request.description(),
                request.price(),
                request.minimumStock(),
                request.active()
        );

        return toResponse(product);
    }

    private ProductResponse toResponse(Product product) {

        return new ProductResponse(
                product.getId(),
                product.getName(),
                product.getSku(),
                product.getDescription(),
                product.getMinimumStock(),
                product.getPrice(),
                product.isActive(),
                product.getCreatedAt(),
                product.getUpdatedAt()
        );
    }
}