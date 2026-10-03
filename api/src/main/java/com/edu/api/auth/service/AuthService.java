package com.edu.api.auth.service;

import com.edu.api.auth.dto.AdminUserResponse;
import com.edu.api.auth.dto.AuthResponse;
import com.edu.api.auth.dto.LoginRequest;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;
import com.edu.api.shared.exception.UnauthorizedException;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class AuthService {

    private final AdminUserRepository adminUserRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    /**
     * Hash de uma senha que ninguém tem. Com e-mail desconhecido o login compara
     * a senha contra ele e leva o mesmo tempo de um e-mail cadastrado: o tempo
     * de resposta não revela quais e-mails existem.
     */
    private final String unknownUserHash;

    public AuthService(
            AdminUserRepository adminUserRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService
    ) {
        this.adminUserRepository = adminUserRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.unknownUserHash = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    public AuthResponse login(LoginRequest request) {

        AdminUser user = adminUserRepository
                .findByEmail(request.email())
                .orElse(null);

        boolean passwordMatches = passwordEncoder.matches(
                request.password(),
                user == null ? unknownUserHash : user.getPassword()
        );

        if (user == null || !passwordMatches) {
            throw new UnauthorizedException("Email ou senha inválidos");
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