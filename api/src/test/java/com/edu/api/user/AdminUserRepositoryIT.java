package com.edu.api.user;

import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class AdminUserRepositoryIT extends OracleIntegrationTest {

    @Autowired
    private AdminUserRepository users;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void findsUserByEmail() {
        users.save(new AdminUser("Ana Souza", "ana@edu.com", "hash", "USER"));
        entityManager.flush();
        entityManager.clear();

        assertThat(users.findByEmail("ana@edu.com"))
                .get()
                .extracting(AdminUser::getRole)
                .isEqualTo("USER");
        assertThat(users.findByEmail("outra@edu.com")).isEmpty();
    }

    @Test
    void rejectsDuplicateEmail() {
        users.saveAndFlush(new AdminUser("Ana Souza", "ana@edu.com", "hash", "USER"));

        assertThatThrownBy(() -> users.saveAndFlush(
                new AdminUser("Ana Clara", "ana@edu.com", "hash", "USER")))
                .isInstanceOf(DataIntegrityViolationException.class);
    }
}
