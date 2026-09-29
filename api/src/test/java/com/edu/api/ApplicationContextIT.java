package com.edu.api;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Smoke do contexto completo: wiring, validate do Hibernate e a cadeia de
 * segurança real. Não depende de dados; o banco está vazio.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ApplicationContextIT extends OracleIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void protectedEndpointRequiresToken() throws Exception {
        mockMvc.perform(get("/products"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
    }

    @Test
    void loginOfUnknownUserIsUnauthorized() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"ninguem@edu.com\",\"password\":\"qualquer\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
    }
}
