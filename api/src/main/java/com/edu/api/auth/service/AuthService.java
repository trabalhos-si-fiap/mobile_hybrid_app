package com.edu.api.auth.service;

import com.edu.api.auth.dto.AdminUserResponse;
import com.edu.api.auth.dto.AuthResponse;
import com.edu.api.auth.dto.LoginRequest;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private final AdminUserRepository adminUserRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(
            AdminUserRepository adminUserRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService
    ) {
        this.adminUserRepository = adminUserRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    public AuthResponse login(LoginRequest request) {

        AdminUser user = adminUserRepository
                .findByEmail(request.email())
                .orElseThrow(() ->
                        new RuntimeException("Email ou senha inválidos")
                );

        if (!passwordEncoder.matches(
                request.password(),
                user.getPassword()
        )) {
            throw new RuntimeException("Email ou senha inválidos");
        }

        AdminUserResponse userResponse = new AdminUserResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getRole()
        );

        String token = jwtService.generateToken(
        user.getId(),
        user.getEmail(),
        user.getRole()
        );

        return new AuthResponse(
                token,
                "Bearer",
                userResponse
        );
    }
}