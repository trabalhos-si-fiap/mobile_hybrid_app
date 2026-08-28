package com.edu.api.inventory.controller;

import com.edu.api.inventory.dto.AdjustInventoryRequest;
import com.edu.api.inventory.dto.InventoryResponse;
import com.edu.api.inventory.service.InventoryService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/inventory")
public class InventoryController {

    private final InventoryService inventoryService;

    public InventoryController(InventoryService inventoryService) {
        this.inventoryService = inventoryService;
    }

    @GetMapping
    public ResponseEntity<Page<InventoryResponse>> findAll(
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "false") boolean lowStock,

            @PageableDefault(
                    size = 10,
                    sort = "product.name",
                    direction = Sort.Direction.ASC
            )
            Pageable pageable
    ) {

        Page<InventoryResponse> response =
                inventoryService.findAll(search, lowStock, pageable);

        return ResponseEntity.ok(response);
    }

    @PatchMapping("/{productId}")
    public ResponseEntity<InventoryResponse> adjust(
            @PathVariable Long productId,

            @Valid
            @RequestBody AdjustInventoryRequest request
    ) {

        InventoryResponse response =
                inventoryService.adjust(productId, request);

        return ResponseEntity.ok(response);
    }
}