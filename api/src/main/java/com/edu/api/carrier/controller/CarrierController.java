package com.edu.api.carrier.controller;

import com.edu.api.carrier.dto.CarrierRequest;
import com.edu.api.carrier.dto.CarrierResponse;
import com.edu.api.carrier.dto.UpdateCarrierStatusRequest;
import com.edu.api.carrier.entity.CarrierStatus;
import com.edu.api.carrier.service.CarrierService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/carriers")
public class CarrierController {

    private final CarrierService carrierService;

    public CarrierController(CarrierService carrierService) {
        this.carrierService = carrierService;
    }

    @GetMapping
    public ResponseEntity<Page<CarrierResponse>> findAll(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) CarrierStatus status,
            @PageableDefault(
                    size = 10,
                    sort = "name",
                    direction = Sort.Direction.ASC
            ) Pageable pageable
    ) {

        return ResponseEntity.ok(
                carrierService.findAll(
                        search,
                        status,
                        pageable
                )
        );
    }

    @GetMapping("/{carrierId}")
    public ResponseEntity<CarrierResponse> findById(
            @PathVariable Long carrierId
    ) {

        return ResponseEntity.ok(
                carrierService.findById(carrierId)
        );
    }

    @PostMapping
    public ResponseEntity<CarrierResponse> create(
            @Valid @RequestBody CarrierRequest request
    ) {

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(carrierService.create(request));
    }

    @PutMapping("/{carrierId}")
    public ResponseEntity<CarrierResponse> update(
            @PathVariable Long carrierId,
            @Valid @RequestBody CarrierRequest request
    ) {

        return ResponseEntity.ok(
                carrierService.update(
                        carrierId,
                        request
                )
        );
    }

    @PatchMapping("/{carrierId}/status")
    public ResponseEntity<CarrierResponse> updateStatus(
            @PathVariable Long carrierId,
            @Valid @RequestBody UpdateCarrierStatusRequest request
    ) {

        return ResponseEntity.ok(
                carrierService.updateStatus(
                        carrierId,
                        request
                )
        );
    }
}