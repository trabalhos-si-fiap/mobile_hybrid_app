package com.edu.api.security;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Os corpos de 401 e 403 saem da cadeia de segurança, fora do Spring MVC. JSON
 * tem de ir em UTF-8: o browser decodifica o JSON de um XHR sempre como UTF-8,
 * e em ISO-8859-1 os acentos das mensagens viram lixo.
 */
class SecurityErrorBodiesTest {

    private final MockHttpServletRequest request = new MockHttpServletRequest("GET", "/products");
    private final MockHttpServletResponse response = new MockHttpServletResponse();

    private String bodyAsUtf8() {
        return new String(response.getContentAsByteArray(), StandardCharsets.UTF_8);
    }

    @Test
    void forbiddenBodyIsUtf8Json() throws Exception {
        new JwtAccessDeniedHandler().handle(request, response, new AccessDeniedException("negado"));

        assertThat(response.getStatus()).isEqualTo(403);
        assertThat(response.getContentType()).isEqualTo("application/json;charset=UTF-8");
        assertThat(bodyAsUtf8()).contains("Você não possui permissão");
    }

    @Test
    void unauthorizedBodyIsUtf8Json() throws Exception {
        new JwtAuthenticationEntryPoint().commence(request, response, new BadCredentialsException("sem token"));

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getContentType()).isEqualTo("application/json;charset=UTF-8");
        assertThat(bodyAsUtf8()).contains("Token inválido");
    }
}
