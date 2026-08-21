package com.edu.api.dashboard.service;

import com.edu.api.carrier.entity.CarrierStatus;
import com.edu.api.carrier.repository.CarrierRepository;
import com.edu.api.dashboard.dto.CarrierDashboardResponse;
import com.edu.api.dashboard.dto.DashboardResponse;
import com.edu.api.dashboard.dto.EducationalDashboardResponse;
import com.edu.api.dashboard.dto.LowStockProductResponse;
import com.edu.api.dashboard.dto.OperationalDashboardResponse;
import com.edu.api.dashboard.dto.RecentOccurrenceResponse;
import com.edu.api.dashboard.provider.EducationalMetricsProvider;
import com.edu.api.inventory.entity.Inventory;
import com.edu.api.inventory.repository.InventoryRepository;
import com.edu.api.occurrence.entity.CarrierOccurrence;
import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.repository.CarrierOccurrenceRepository;
import com.edu.api.product.repository.ProductRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class DashboardService {

    private final EducationalMetricsProvider educationalMetricsProvider;
    private final ProductRepository productRepository;
    private final InventoryRepository inventoryRepository;
    private final CarrierRepository carrierRepository;
    private final CarrierOccurrenceRepository occurrenceRepository;
    private final InsightGenerator insightGenerator;

    public DashboardService(
            EducationalMetricsProvider educationalMetricsProvider,
            ProductRepository productRepository,
            InventoryRepository inventoryRepository,
            CarrierRepository carrierRepository,
            CarrierOccurrenceRepository occurrenceRepository,
            InsightGenerator insightGenerator
    ) {
        this.educationalMetricsProvider = educationalMetricsProvider;
        this.productRepository = productRepository;
        this.inventoryRepository = inventoryRepository;
        this.carrierRepository = carrierRepository;
        this.occurrenceRepository = occurrenceRepository;
        this.insightGenerator = insightGenerator;
    }

    @Transactional(readOnly = true)
    public DashboardResponse getDashboard(int days) {

        EducationalDashboardResponse educational =
                educationalMetricsProvider.getMetrics(days);

        OperationalDashboardResponse operational =
                buildOperationalDashboard();

        String executiveSummary =
                insightGenerator.generate(
                        educational,
                        operational
                );

        return new DashboardResponse(
                educational,
                operational,
                executiveSummary
        );
    }

    private OperationalDashboardResponse buildOperationalDashboard() {

        long registeredProducts =
                productRepository.count();

        long lowStockProducts =
                inventoryRepository.countBelowMinimum();

        long activeCarriers =
                carrierRepository.countByStatus(
                        CarrierStatus.ACTIVE
                );

        long openOccurrences =
                occurrenceRepository.countByStatus(
                        OccurrenceStatus.OPEN
                );

        List<LowStockProductResponse> lowStock =
                inventoryRepository
                        .findAllBelowMinimum()
                        .stream()
                        .map(this::toLowStockResponse)
                        .toList();

        List<CarrierDashboardResponse> carriers =
                carrierRepository
                        .findByStatus(CarrierStatus.ACTIVE)
                        .stream()
                        .map(carrier ->
                                new CarrierDashboardResponse(
                                        carrier.getId(),
                                        carrier.getName(),
                                        carrier.getRating(),
                                        carrier.getSlaPercentage(),
                                        carrier.getAverageDeliveryDays()
                                )
                        )
                        .toList();

        List<RecentOccurrenceResponse> recentOccurrences =
                occurrenceRepository
                        .findTop5ByOrderByCreatedAtDesc()
                        .stream()
                        .map(this::toRecentOccurrenceResponse)
                        .toList();

        return new OperationalDashboardResponse(
                registeredProducts,
                lowStockProducts,
                activeCarriers,
                openOccurrences,
                lowStock,
                carriers,
                recentOccurrences
        );
    }

    private LowStockProductResponse toLowStockResponse(
            Inventory inventory
    ) {

        return new LowStockProductResponse(
                inventory.getProduct().getId(),
                inventory.getProduct().getName(),
                inventory.getProduct().getSku(),
                inventory.getQuantity(),
                inventory.getProduct().getMinimumStock(),
                getInventoryStatus(inventory)
        );
    }

    private String getInventoryStatus(Inventory inventory) {

        if (inventory.getQuantity() == 0) {
            return "OUT_OF_STOCK";
        }

        if (inventory.getQuantity()
                < inventory.getProduct().getMinimumStock()) {
            return "LOW_STOCK";
        }

        return "NORMAL";
    }

    private RecentOccurrenceResponse toRecentOccurrenceResponse(
            CarrierOccurrence occurrence
    ) {

        return new RecentOccurrenceResponse(
                occurrence.getId(),
                occurrence.getType(),
                occurrence.getCarrier().getName(),
                occurrence.getCreatedAt(),
                occurrence.getStatus()
        );
    }
}