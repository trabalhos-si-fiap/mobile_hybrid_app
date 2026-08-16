package com.edu.api.product.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.edu.api.product.dto.*;
import com.edu.api.product.service.ProductService;

@RestController
@RequestMapping("/products")
public class ProductController {
    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping
    public List<ProductResponse> listProducts() {
        return productService.findAll();
    }

    @PostMapping
    public ProductResponse createProduct(ProductRequest request) {
        return productService.create(request);
    }

    @GetMapping("/{id}")
    public ProductResponse getProductById(Long id) {
        return productService.findById(id); 
    }

    @PutMapping
    public ProductResponse updateProduct(Long id, ProductRequest request) {
        return productService.update(id, request);
    }   
}
