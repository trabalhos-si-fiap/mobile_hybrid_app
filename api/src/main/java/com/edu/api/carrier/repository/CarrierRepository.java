package com.edu.api.carrier.repository;

import com.edu.api.carrier.entity.Carrier;
import com.edu.api.carrier.entity.CarrierStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CarrierRepository extends JpaRepository<Carrier, Long> {

    Page<Carrier> findByStatus(
            CarrierStatus status,
            Pageable pageable
    );

    List<Carrier> findByStatus(
            CarrierStatus status
    );

    Page<Carrier> findByNameContainingIgnoreCase(
            String name,
            Pageable pageable
    );

    Page<Carrier> findByNameContainingIgnoreCaseAndStatus(
            String name,
            CarrierStatus status,
            Pageable pageable
    );

    long countByStatus(CarrierStatus status);
}