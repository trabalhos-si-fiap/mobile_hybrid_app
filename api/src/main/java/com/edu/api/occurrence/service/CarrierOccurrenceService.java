package com.edu.api.occurrence.service;

import com.edu.api.carrier.entity.Carrier;
import com.edu.api.carrier.repository.CarrierRepository;
import com.edu.api.occurrence.dto.CarrierOccurrenceResponse;
import com.edu.api.occurrence.dto.CreateCarrierOccurrenceRequest;
import com.edu.api.occurrence.dto.UpdateOccurrenceStatusRequest;
import com.edu.api.occurrence.entity.CarrierOccurrence;
import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.entity.OccurrenceType;
import com.edu.api.occurrence.repository.CarrierOccurrenceRepository;
import com.edu.api.shared.exception.BusinessException;
import com.edu.api.shared.exception.NotFoundException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CarrierOccurrenceService {

    private final CarrierOccurrenceRepository occurrenceRepository;
    private final CarrierRepository carrierRepository;

    public CarrierOccurrenceService(
            CarrierOccurrenceRepository occurrenceRepository,
            CarrierRepository carrierRepository
    ) {
        this.occurrenceRepository = occurrenceRepository;
        this.carrierRepository = carrierRepository;
    }

    @Transactional(readOnly = true)
    public Page<CarrierOccurrenceResponse> findAll(
            Long carrierId,
            OccurrenceType type,
            OccurrenceStatus status,
            Pageable pageable
    ) {

        Page<CarrierOccurrence> occurrences;

        if (carrierId != null && type != null && status != null) {

            occurrences = occurrenceRepository
                    .findByCarrierIdAndTypeAndStatus(
                            carrierId,
                            type,
                            status,
                            pageable
                    );

        } else if (carrierId != null && type != null) {

            occurrences = occurrenceRepository
                    .findByCarrierIdAndType(
                            carrierId,
                            type,
                            pageable
                    );

        } else if (carrierId != null && status != null) {

            occurrences = occurrenceRepository
                    .findByCarrierIdAndStatus(
                            carrierId,
                            status,
                            pageable
                    );

        } else if (type != null && status != null) {

            occurrences = occurrenceRepository
                    .findByTypeAndStatus(
                            type,
                            status,
                            pageable
                    );

        } else if (carrierId != null) {

            occurrences = occurrenceRepository
                    .findByCarrierId(
                            carrierId,
                            pageable
                    );

        } else if (type != null) {

            occurrences = occurrenceRepository
                    .findByType(
                            type,
                            pageable
                    );

        } else if (status != null) {

            occurrences = occurrenceRepository
                    .findByStatus(
                            status,
                            pageable
                    );

        } else {

            occurrences = occurrenceRepository.findAll(pageable);
        }

        return occurrences.map(this::toResponse);
    }

    @Transactional
    public CarrierOccurrenceResponse create(
            CreateCarrierOccurrenceRequest request
    ) {

        Carrier carrier = carrierRepository
                .findById(request.carrierId())
                .orElseThrow(() ->
                        new NotFoundException(
                                "Transportadora não encontrada"
                        )
                );

        CarrierOccurrence occurrence = new CarrierOccurrence(
                carrier,
                request.type(),
                request.description()
        );

        occurrenceRepository.save(occurrence);

        return toResponse(occurrence);
    }

    @Transactional(readOnly = true)
    public CarrierOccurrenceResponse findById(Long id) {

        CarrierOccurrence occurrence = occurrenceRepository
                .findById(id)
                .orElseThrow(() ->
                        new NotFoundException(
                                "Ocorrência não encontrada"
                        )
                );

        return toResponse(occurrence);
    }

    @Transactional
    public CarrierOccurrenceResponse updateStatus(
            Long id,
            UpdateOccurrenceStatusRequest request
    ) {

        CarrierOccurrence occurrence = occurrenceRepository
                .findById(id)
                .orElseThrow(() ->
                        new NotFoundException(
                                "Ocorrência não encontrada"
                        )
                );

        if (occurrence.getStatus() == OccurrenceStatus.RESOLVED
                && request.status() == OccurrenceStatus.OPEN) {

            throw new BusinessException(
                    "Uma ocorrência resolvida não pode voltar para OPEN"
            );
        }

        occurrence.updateStatus(request.status());

        return toResponse(occurrence);
    }

    private CarrierOccurrenceResponse toResponse(
            CarrierOccurrence occurrence
    ) {

        return new CarrierOccurrenceResponse(
                occurrence.getId(),
                occurrence.getCarrier().getId(),
                occurrence.getCarrier().getName(),
                occurrence.getType(),
                occurrence.getDescription(),
                occurrence.getStatus(),
                occurrence.getCreatedAt(),
                occurrence.getResolvedAt()
        );
    }
}