package com.edu.api.user.entity;

import jakarta.persistence.*;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Getter
@Entity
@Table(name = "admin_users")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AdminUser {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false, unique = true, length = 254)
    private String email;

    @Column(nullable = false, length = 255)
    private String password;

    @Column(nullable = false, length = 20)
    private String role;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public AdminUser(
            String name,
            String email,
            String password,
            String role
    ) {
        this.name = name;
        this.email = email;
        this.password = password;
        this.role = role;
    }

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
    }
}