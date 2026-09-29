package com.edu.api.auth.service;

import com.edu.api.security.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class JwtServiceTest {

    private final JwtService jwt = new JwtService("test-secret-key-for-jwt-tests-edu-admin", 60);

    @Test
    void parsesTheClaimsOfAnIssuedToken() {
        String token = jwt.generateToken(42L, "ana@edu.com", "EMPLOYEE");

        assertThat(jwt.parse(token)).contains(new AuthenticatedUser(42L, "ana@edu.com", "EMPLOYEE"));
    }

    @Test
    void rejectsATamperedToken() {
        String token = jwt.generateToken(42L, "ana@edu.com", "USER");
        String tampered = token.substring(0, token.length() - 2) + (token.endsWith("AA") ? "BB" : "AA");

        assertThat(jwt.parse(tampered)).isEmpty();
    }

    @Test
    void rejectsSomethingThatIsNotAToken() {
        assertThat(jwt.parse("nao-e-um-jwt")).isEmpty();
    }
}
