package com.edu.api.product.service;

import com.edu.api.product.dto.ProductRequest;
import com.edu.api.product.dto.ProductResponse;
import com.edu.api.product.entity.Product;
import com.edu.api.product.repository.ProductRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ProductService {

    private final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    @Transactional
    public ProductResponse create(ProductRequest request) {

        Product product = new Product(
                request.name(),
                request.description(),
                request.price(),
                request.minimumStock()
        );

        productRepository.save(product);

        product.updateSku(
                String.format("EDU-%04d", product.getId())
        );

        productRepository.save(product);

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
                        new RuntimeException("Produto não encontrado")
                );

        return toResponse(product);
    }

    @Transactional
    public ProductResponse update(Long id, ProductRequest request) {

        Product product = productRepository.findById(id)
                .orElseThrow(() ->
                        new RuntimeException("Produto não encontrado")
                );

        product.update(
                request.name(),
                request.description(),
                request.price(),
                request.minimumStock()
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