package com.edu.api.carrier.service;

import com.edu.api.carrier.dto.CarrierRequest;
import com.edu.api.carrier.dto.CarrierResponse;
import com.edu.api.carrier.dto.UpdateCarrierStatusRequest;
import com.edu.api.carrier.entity.Carrier;
import com.edu.api.carrier.entity.CarrierStatus;
import com.edu.api.carrier.repository.CarrierRepository;
import com.edu.api.shared.exception.NotFoundException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CarrierService {

    private final CarrierRepository carrierRepository;

    public CarrierService(CarrierRepository carrierRepository) {
        this.carrierRepository = carrierRepository;
    }

    @Transactional(readOnly = true)
    public Page<CarrierResponse> findAll(
            String search,
            CarrierStatus status,
            Pageable pageable
    ) {

        Page<Carrier> carriers;

        if (search != null && !search.isBlank() && status != null) {

            carriers = carrierRepository
                    .findByNameContainingIgnoreCaseAndStatus(
                            search,
                            status,
                            pageable
                    );

        } else if (search != null && !search.isBlank()) {

            carriers = carrierRepository
                    .findByNameContainingIgnoreCase(
                            search,
                            pageable
                    );

        } else if (status != null) {

            carriers = carrierRepository
                    .findByStatus(
                            status,
                            pageable
                    );

        } else {

            carriers = carrierRepository.findAll(pageable);
        }

        return carriers.map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public CarrierResponse findById(Long id) {

        Carrier carrier = carrierRepository
                .findById(id)
                .orElseThrow(() ->
                        new NotFoundException(
                                "Transportadora não encontrada"
                        )
                );

        return toResponse(carrier);
    }

    @Transactional
    public CarrierResponse create(CarrierRequest request) {

        Carrier carrier = new Carrier(
                request.name(),
                request.location(),
                request.email(),
                request.averageDeliveryDays(),
                request.rating(),
                request.slaPercentage(),
                request.status()
        );

        carrierRepository.save(carrier);

        return toResponse(carrier);
    }

    @Transactional
    public CarrierResponse update(
            Long id,
            CarrierRequest request
    ) {

        Carrier carrier = carrierRepository
                .findById(id)
                .orElseThrow(() ->
                        new NotFoundException(
                                "Transportadora não encontrada"
                        )
                );

        carrier.update(
                request.name(),
                request.location(),
                request.email(),
                request.averageDeliveryDays(),
                request.rating(),
                request.slaPercentage(),
                request.status()
        );

        return toResponse(carrier);
    }

    @Transactional
    public CarrierResponse updateStatus(
            Long id,
            UpdateCarrierStatusRequest request
    ) {

        Carrier carrier = carrierRepository
                .findById(id)
                .orElseThrow(() ->
                        new NotFoundException(
                                "Transportadora não encontrada"
                        )
                );

        carrier.updateStatus(request.status());

        return toResponse(carrier);
    }

    private CarrierResponse toResponse(Carrier carrier) {

        return new CarrierResponse(
                carrier.getId(),
                carrier.getName(),
                carrier.getLocation(),
                carrier.getEmail(),
                carrier.getAverageDeliveryDays(),
                carrier.getRating(),
                carrier.getSlaPercentage(),
                carrier.getStatus(),
                carrier.getCreatedAt(),
                carrier.getUpdatedAt()
        );
    }
}