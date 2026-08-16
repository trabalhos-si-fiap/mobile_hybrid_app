package com.edu.api.carrier.repository;

import com.edu.api.carrier.entity.Carrier;
import com.edu.api.carrier.entity.CarrierStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CarrierRepository extends JpaRepository<Carrier, Long> {

    Page<Carrier> findByStatus(
            CarrierStatus status,
            Pageable pageable
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
}