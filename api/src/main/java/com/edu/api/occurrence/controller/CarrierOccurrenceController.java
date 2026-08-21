package com.edu.api.occurrence.controller;

import com.edu.api.occurrence.dto.CarrierOccurrenceResponse;
import com.edu.api.occurrence.dto.CreateCarrierOccurrenceRequest;
import com.edu.api.occurrence.dto.UpdateOccurrenceStatusRequest;
import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.entity.OccurrenceType;
import com.edu.api.occurrence.service.CarrierOccurrenceService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/carrier-occurrences")
public class CarrierOccurrenceController {

    private final CarrierOccurrenceService occurrenceService;

    public CarrierOccurrenceController(
            CarrierOccurrenceService occurrenceService
    ) {
        this.occurrenceService = occurrenceService;
    }

    @GetMapping
    public ResponseEntity<Page<CarrierOccurrenceResponse>> findAll(
            @RequestParam(required = false) Long carrierId,
            @RequestParam(required = false) OccurrenceType type,
            @RequestParam(required = false) OccurrenceStatus status,
            @PageableDefault(
                    size = 10,
                    sort = "createdAt",
                    direction = Sort.Direction.DESC
            ) Pageable pageable
    ) {

        return ResponseEntity.ok(
                occurrenceService.findAll(
                        carrierId,
                        type,
                        status,
                        pageable
                )
        );
    }

    @PostMapping
    public ResponseEntity<CarrierOccurrenceResponse> create(
            @Valid @RequestBody CreateCarrierOccurrenceRequest request
    ) {

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(occurrenceService.create(request));
    }

    @GetMapping("/{occurrenceId}")
    public ResponseEntity<CarrierOccurrenceResponse> findById(
            @PathVariable Long occurrenceId
    ) {

        return ResponseEntity.ok(
                occurrenceService.findById(occurrenceId)
        );
    }

    @PatchMapping("/{occurrenceId}/status")
    public ResponseEntity<CarrierOccurrenceResponse> updateStatus(
            @PathVariable Long occurrenceId,
            @Valid @RequestBody UpdateOccurrenceStatusRequest request
    ) {

        return ResponseEntity.ok(
                occurrenceService.updateStatus(
                        occurrenceId,
                        request
                )
        );
    }
}