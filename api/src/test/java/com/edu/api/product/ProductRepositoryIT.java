package com.edu.api.product;

import com.edu.api.inventory.entity.Inventory;
import com.edu.api.product.entity.Product;
import com.edu.api.product.repository.ProductRepository;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class ProductRepositoryIT extends OracleIntegrationTest {

    @Autowired
    private ProductRepository products;

    @Autowired
    private TestEntityManager entityManager;

    /** Relê do banco, e não do cache de primeiro nível. */
    private Product reload(Product product) {
        entityManager.flush();
        entityManager.clear();
        return products.findById(product.getId()).orElseThrow();
    }

    private Product newProduct(String name, String description) {
        return new Product(name, description, new BigDecimal("9.90"), 3);
    }

    @Test
    void generatesDistinctIdsForNewProducts() {
        Product first = products.save(newProduct("Lápis HB", "Grafite nº 2"));
        Product second = products.save(newProduct("Apontador", "Com depósito"));
        entityManager.flush();

        assertThat(first.getId()).isNotNull();
        assertThat(second.getId()).isNotNull().isNotEqualTo(first.getId());
    }

    @Test
    void keepsAccentedText() {
        Product saved = products.save(newProduct(
                "Caderno Universitário", "Capa dura — 200 folhas, pautação ção"));

        Product found = reload(saved);

        assertThat(found.getName()).isEqualTo("Caderno Universitário");
        assertThat(found.getDescription()).isEqualTo("Capa dura — 200 folhas, pautação ção");
    }

    @Test
    void persistsInactiveFlag() {
        Product saved = products.save(newProduct("Régua 30cm", "Acrílica"));
        saved.update(saved.getName(), saved.getDescription(), saved.getPrice(),
                saved.getMinimumStock(), false);

        assertThat(reload(saved).isActive()).isFalse();
    }

    @Test
    void persistsProductWithInventory() {
        Product product = newProduct("Mochila", "Reforçada");
        new Inventory(product, 7);
        products.save(product);

        Product found = reload(product);

        assertThat(found.getInventory().getQuantity()).isEqualTo(7);
    }
}
