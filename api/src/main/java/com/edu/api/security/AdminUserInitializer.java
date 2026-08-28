package com.edu.api.security;

import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class AdminUserInitializer {

    @Bean
    CommandLineRunner createDefaultAdmin(
            AdminUserRepository repository,
            PasswordEncoder passwordEncoder
    ) {
        return args -> {

            if (repository.findByEmail("admin@edu.com").isEmpty()) {

                AdminUser admin = new AdminUser(
                        "Administrador Edu",
                        "admin@edu.com",
                        passwordEncoder.encode("admin123"),
                        "ADMIN"
                );

                repository.save(admin);

                System.out.println("Administrador padrão criado.");
            }
        };
    }
}