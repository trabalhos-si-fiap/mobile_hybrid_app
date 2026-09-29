package com.edu.api.support;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.oracle.OracleContainer;

/**
 * Base dos testes de integração. Um único Oracle efêmero é iniciado por JVM
 * e compartilhado por todos os contextos; o Ryuk do Testcontainers o remove
 * ao fim da execução. O schema nasce vazio, então cada teste cria os
 * próprios dados.
 */
public abstract class OracleIntegrationTest {

    private static final OracleContainer ORACLE =
            new OracleContainer("gvenzl/oracle-free:23-slim-faststart")
                    .withUsername("edu_admin")
                    .withPassword("edu_admin");

    static {
        ORACLE.start();
    }

    @DynamicPropertySource
    static void oracleProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", ORACLE::getJdbcUrl);
        registry.add("spring.datasource.username", ORACLE::getUsername);
        registry.add("spring.datasource.password", ORACLE::getPassword);
    }
}
