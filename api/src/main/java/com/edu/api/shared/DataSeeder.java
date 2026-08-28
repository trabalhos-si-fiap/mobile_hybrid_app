package com.edu.api.shared;

import com.edu.api.carrier.entity.Carrier;
import com.edu.api.carrier.entity.CarrierStatus;
import com.edu.api.carrier.repository.CarrierRepository;
import com.edu.api.inventory.entity.Inventory;
import com.edu.api.inventory.repository.InventoryRepository;
import com.edu.api.occurrence.entity.CarrierOccurrence;
import com.edu.api.occurrence.entity.OccurrenceType;
import com.edu.api.occurrence.repository.CarrierOccurrenceRepository;
import com.edu.api.product.entity.Product;
import com.edu.api.product.repository.ProductRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.math.BigDecimal;

/**
 * Popula o banco com dados de demonstração na primeira inicialização.
 * Idempotente: só insere se as tabelas estiverem vazias.
 */
@Configuration
public class DataSeeder {

    @Bean
    CommandLineRunner seedDemoData(
            ProductRepository productRepo,
            InventoryRepository inventoryRepo,
            CarrierRepository carrierRepo,
            CarrierOccurrenceRepository occurrenceRepo
    ) {
        return args -> {
            seedCarriers(carrierRepo, occurrenceRepo);
            seedProducts(productRepo, inventoryRepo);
        };
    }

    // -------------------------------------------------------------------------
    // Transportadoras + Ocorrências
    // -------------------------------------------------------------------------

    private void seedCarriers(CarrierRepository carrierRepo,
                               CarrierOccurrenceRepository occurrenceRepo) {
        if (carrierRepo.count() > 0) return;

        Carrier c1 = carrierRepo.save(new Carrier(
                "Rapidex Logística", "São Paulo, SP", "contato@rapidex.com.br",
                2, new BigDecimal("4.7"), new BigDecimal("96.50"), CarrierStatus.ACTIVE));

        Carrier c2 = carrierRepo.save(new Carrier(
                "TotalFrete Express", "Rio de Janeiro, RJ", "ops@totalfrete.com.br",
                3, new BigDecimal("4.2"), new BigDecimal("89.80"), CarrierStatus.ACTIVE));

        Carrier c3 = carrierRepo.save(new Carrier(
                "Nordeste Cargas", "Fortaleza, CE", "comercial@nordestecargas.com.br",
                5, new BigDecimal("3.8"), new BigDecimal("82.10"), CarrierStatus.ACTIVE));

        carrierRepo.save(new Carrier(
                "Sul Expresso", "Porto Alegre, RS", "atendimento@sulexpresso.com.br",
                4, new BigDecimal("4.0"), new BigDecimal("91.30"), CarrierStatus.INACTIVE));

        // Ocorrências abertas
        occurrenceRepo.save(new CarrierOccurrence(c1,
                OccurrenceType.DELIVERY_DELAY,
                "Pedido #4521 com atraso de 2 dias por greve de rodoviários na SP-330."));

        occurrenceRepo.save(new CarrierOccurrence(c2,
                OccurrenceType.DAMAGE,
                "Caixa do pedido #3870 chegou amassada. Cliente solicitou reenvio."));

        occurrenceRepo.save(new CarrierOccurrence(c3,
                OccurrenceType.DELIVERY_FAILURE,
                "Tentativa de entrega sem sucesso — endereço não localizado no pedido #5102."));
    }

    // -------------------------------------------------------------------------
    // Produtos + Estoque (todos abaixo do mínimo para aparecerem como baixo)
    // -------------------------------------------------------------------------

    private void seedProducts(ProductRepository productRepo,
                               InventoryRepository inventoryRepo) {
        if (productRepo.count() > 0) return;

        saveProductWithStock(productRepo, inventoryRepo,
                "Livro de Matemática Vol. 3", "Material didático de álgebra avançada",
                new BigDecimal("89.90"), 10, 2);

        saveProductWithStock(productRepo, inventoryRepo,
                "Caderno Universitário 200fls", "Caderno capa dura para anotações",
                new BigDecimal("24.50"), 20, 4);

        saveProductWithStock(productRepo, inventoryRepo,
                "Kit Canetas Coloridas 12un", "Canetas para mapas mentais e estudos",
                new BigDecimal("18.90"), 15, 1);

        saveProductWithStock(productRepo, inventoryRepo,
                "Apostila Redação ENEM 2025", "Guia completo de redação para o ENEM",
                new BigDecimal("45.00"), 8, 0);

        // Produto com estoque normal (não aparece como baixo)
        saveProductWithStock(productRepo, inventoryRepo,
                "Borracha Branca Faber-Castell", "Borracha de alta qualidade",
                new BigDecimal("3.50"), 5, 30);
    }

    private void saveProductWithStock(ProductRepository productRepo,
                                       InventoryRepository inventoryRepo,
                                       String name, String desc,
                                       BigDecimal price, int minStock, int qty) {
        Product p = productRepo.save(new Product(name, desc, price, minStock));
        inventoryRepo.save(new Inventory(p, qty));
    }
}
