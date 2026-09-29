package com.edu.api.auth.service;

import com.edu.api.security.AuthenticatedUser;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.Optional;

@Service
public class JwtService {

    private final SecretKey secretKey;
    private final long expiration;

    public JwtService(
            @Value("${app.security.jwt-secret}") String secret,
            @Value("${app.security.jwt-expiration-minutes}") long expirationMinutes
    ) {

        this.secretKey = Keys.hmacShaKeyFor(
                secret.getBytes(StandardCharsets.UTF_8)
        );

        this.expiration = expirationMinutes * 60 * 1000L;
    }

    public String generateToken(
            Long userId,
            String email,
            String role
    ) {

        Date now = new Date();

        Date expirationDate = new Date(
                now.getTime() + expiration
        );

        return Jwts.builder()
                .subject(email)
                .claim("userId", userId)
                .claim("role", role)
                .issuedAt(now)
                .expiration(expirationDate)
                .signWith(secretKey)
                .compact();
    }

    /** Claims de um token válido, ou vazio se o token for inválido ou incompleto. */
    public Optional<AuthenticatedUser> parse(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(secretKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();

            Number userId = claims.get("userId", Number.class);
            String role = claims.get("role", String.class);

            if (userId == null || role == null) {
                return Optional.empty();
            }

            return Optional.of(new AuthenticatedUser(userId.longValue(), claims.getSubject(), role));

        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}