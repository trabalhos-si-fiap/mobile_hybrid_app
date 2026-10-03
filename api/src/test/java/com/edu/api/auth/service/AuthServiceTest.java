package com.edu.api.auth.service;

import com.edu.api.auth.dto.AuthResponse;
import com.edu.api.auth.dto.LoginRequest;
import com.edu.api.shared.exception.UnauthorizedException;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private AdminUserRepository adminUserRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @InjectMocks
    private AuthService authService;

    private final AdminUser admin = new AdminUser("Admin", "admin@edu.com", "hash", "ADMIN");

    @Test
    void returnsTokenAndUserWhenCredentialsMatch() {
        when(adminUserRepository.findByEmail("admin@edu.com")).thenReturn(Optional.of(admin));
        when(passwordEncoder.matches("secret", "hash")).thenReturn(true);
        when(jwtService.generateToken(null, "admin@edu.com", "ADMIN")).thenReturn("jwt");

        AuthResponse response = authService.login(new LoginRequest("admin@edu.com", "secret"));

        assertThat(response.accessToken()).isEqualTo("jwt");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.user().email()).isEqualTo("admin@edu.com");
        assertThat(response.user().role()).isEqualTo("ADMIN");
    }

    @Test
    void rejectsWrongPassword() {
        when(adminUserRepository.findByEmail("admin@edu.com")).thenReturn(Optional.of(admin));
        when(passwordEncoder.matches("wrong", "hash")).thenReturn(false);

        assertThatThrownBy(() -> authService.login(new LoginRequest("admin@edu.com", "wrong")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage("Email ou senha inválidos");
        verifyNoInteractions(jwtService);
    }

    @Test
    void comparesThePasswordEvenWhenTheEmailIsUnknown() {
        when(passwordEncoder.encode(anyString())).thenReturn("hash-de-ninguem");
        AuthService service = new AuthService(adminUserRepository, passwordEncoder, jwtService);
        when(adminUserRepository.findByEmail("nobody@edu.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.login(new LoginRequest("nobody@edu.com", "any")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage("Email ou senha inválidos");
        verify(passwordEncoder).matches("any", "hash-de-ninguem");
        verifyNoInteractions(jwtService);
    }
}
