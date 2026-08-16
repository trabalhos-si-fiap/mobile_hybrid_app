package com.edu.api.product.controller;

import com.edu.api.product.dto.CreateProductRequest;
import com.edu.api.product.dto.ProductResponse;
import com.edu.api.product.dto.UpdateProductRequest;
import com.edu.api.product.service.ProductService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/products")
public class ProductController {

    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping
    public ResponseEntity<List<ProductResponse>> findAll() {

        return ResponseEntity.ok(
                productService.findAll()
        );
    }

    @PostMapping
    public ResponseEntity<ProductResponse> create(
            @Valid @RequestBody CreateProductRequest request
    ) {

        ProductResponse response = productService.create(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }

    @GetMapping("/{productId}")
    public ResponseEntity<ProductResponse> findById(
            @PathVariable Long productId
    ) {

        return ResponseEntity.ok(
                productService.findById(productId)
        );
    }

    @PutMapping("/{productId}")
    public ResponseEntity<ProductResponse> update(
            @PathVariable Long productId,
            @Valid @RequestBody UpdateProductRequest request
    ) {

        return ResponseEntity.ok(
                productService.update(productId, request)
        );
    }
}