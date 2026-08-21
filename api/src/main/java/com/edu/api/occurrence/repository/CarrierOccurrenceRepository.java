package com.edu.api.occurrence.repository;

import com.edu.api.occurrence.entity.CarrierOccurrence;
import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.entity.OccurrenceType;

import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CarrierOccurrenceRepository
        extends JpaRepository<CarrierOccurrence, Long> {

    Page<CarrierOccurrence> findByCarrierId(
            Long carrierId,
            Pageable pageable
    );

    Page<CarrierOccurrence> findByType(
            OccurrenceType type,
            Pageable pageable
    );

    Page<CarrierOccurrence> findByStatus(
            OccurrenceStatus status,
            Pageable pageable
    );

    Page<CarrierOccurrence> findByCarrierIdAndType(
            Long carrierId,
            OccurrenceType type,
            Pageable pageable
    );

    Page<CarrierOccurrence> findByCarrierIdAndStatus(
            Long carrierId,
            OccurrenceStatus status,
            Pageable pageable
    );

    Page<CarrierOccurrence> findByTypeAndStatus(
            OccurrenceType type,
            OccurrenceStatus status,
            Pageable pageable
    );

    Page<CarrierOccurrence> findByCarrierIdAndTypeAndStatus(
            Long carrierId,
            OccurrenceType type,
            OccurrenceStatus status,
            Pageable pageable
    );

    long countByStatus(OccurrenceStatus status);

    List<CarrierOccurrence> findTop5ByOrderByCreatedAtDesc();
}