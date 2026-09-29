package com.edu.api.support;

import com.edu.api.auth.service.JwtService;
import com.edu.api.security.AuthenticatedUser;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import jakarta.persistence.EntityManager;

/**
 * Base dos ITs com o contexto completo (Oracle + MinIO efêmeros). Cada teste
 * roda numa transação desfeita ao final; MockMvc executa na mesma thread,
 * então as requisições também entram nela.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
public abstract class FullStackIntegration extends OracleIntegrationTest {

    @DynamicPropertySource
    static void minioProperties(DynamicPropertyRegistry registry) {
        MinioTestContainer.register(registry);
    }

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    protected JdbcTemplate jdbc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private EntityManager entityManager;

    protected TicketFixtures fx;

    @BeforeEach
    void createFixtures() {
        fx = new TicketFixtures(jdbc);
    }

    protected String bearer(long userId, String role) {
        return "Bearer " + jwtService.generateToken(userId, "u" + userId + "@teste.edu", role);
    }

    protected static AuthenticatedUser login(long userId, String role) {
        return new AuthenticatedUser(userId, "u" + userId + "@teste.edu", role);
    }

    /** Envia ao banco o que o Hibernate ainda guarda, antes de conferir via JDBC. */
    protected void flush() {
        entityManager.flush();
    }
}
