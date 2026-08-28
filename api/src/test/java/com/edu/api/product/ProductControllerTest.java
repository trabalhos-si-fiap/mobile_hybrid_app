package com.edu.api.product;

import com.edu.api.product.dto.CreateProductRequest;
import com.edu.api.product.dto.ProductResponse;
import com.edu.api.product.dto.UpdateProductRequest;
import com.edu.api.product.service.ProductService;
import com.edu.api.security.TestSecurityConfig;

import com.fasterxml.jackson.databind.ObjectMapper;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(TestSecurityConfig.class)
class ProductControllerTest {

    @Autowired
    private MockMvc mockMvc;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @MockitoBean
    private ProductService productService;

    private CreateProductRequest validCreateRequest() {

        return new CreateProductRequest(
                "Produto Teste",
                "Descrição do produto teste",
                10,
                new BigDecimal("99.90")
        );
    }

    private UpdateProductRequest validUpdateRequest() {

        return new UpdateProductRequest(
                "Produto Atualizado",
                "Descrição atualizada",
                new BigDecimal("109.90"),
                15,
                true
        );
    }

    private ProductResponse validResponse() {

        Instant now = Instant.now();

        return new ProductResponse(
                1L,
                "Produto Teste",
                "EDU-12345678",
                "Descrição do produto teste",
                10,
                new BigDecimal("99.90"),
                true,
                now,
                now
        );
    }

    @Test
    void shouldFindAllProducts() throws Exception {

        when(productService.findAll())
                .thenReturn(List.of(validResponse()));

        mockMvc.perform(
                get("/products")
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldFindProductById() throws Exception {

        when(productService.findById(1L))
                .thenReturn(validResponse());

        mockMvc.perform(
                get("/products/1")
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldCreateProduct() throws Exception {

        CreateProductRequest request = validCreateRequest();

        when(productService.create(
                any(CreateProductRequest.class)
        )).thenReturn(validResponse());

        mockMvc.perform(
                post("/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isCreated());
    }

    @Test
    void shouldRejectInvalidProduct() throws Exception {

        CreateProductRequest request =
                new CreateProductRequest(
                        "",
                        "",
                        -1,
                        null
                );

        mockMvc.perform(
                post("/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isBadRequest());
    }

    @Test
    void shouldUpdateProduct() throws Exception {

        UpdateProductRequest request = validUpdateRequest();

        when(productService.update(
                eq(1L),
                any(UpdateProductRequest.class)
        )).thenReturn(validResponse());

        mockMvc.perform(
                put("/products/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldRejectInvalidProductUpdate() throws Exception {

        UpdateProductRequest request =
                new UpdateProductRequest(
                        "",
                        "",
                        null,
                        -1,
                        true
                );

        mockMvc.perform(
                put("/products/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isBadRequest());
    }
}