package com.edu.api.security;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.util.List;

/** Usuário autenticado, montado a partir das claims do JWT. */
public record AuthenticatedUser(Long id, String email, String role) {

    public static final String USER = "USER";
    public static final String EMPLOYEE = "EMPLOYEE";
    public static final String ADMIN = "ADMIN";

    public boolean isAdmin() {
        return ADMIN.equals(role);
    }

    public boolean isStaff() {
        return EMPLOYEE.equals(role) || ADMIN.equals(role);
    }

    public List<GrantedAuthority> authorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role));
    }
}
