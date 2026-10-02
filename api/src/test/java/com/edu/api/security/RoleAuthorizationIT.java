package com.edu.api.security;

import com.edu.api.auth.service.JwtService;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.http.HttpHeaders.AUTHORIZATION;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Cadeia de segurança real: papéis vêm do token. Nenhum dado é necessário. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class RoleAuthorizationIT extends OracleIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwt;

    private String bearer(String role) {
        return "Bearer " + jwt.generateToken(999L, role.toLowerCase() + "@teste.edu", role);
    }

    @Test
    void userIsForbiddenOnManagementEndpoints() throws Exception {
        mockMvc.perform(get("/products").header(AUTHORIZATION, bearer("USER")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    @Test
    void employeeCanReadProducts() throws Exception {
        mockMvc.perform(get("/products").header(AUTHORIZATION, bearer("EMPLOYEE")))
                .andExpect(status().isOk());
    }

    @Test
    void adminCanReadProducts() throws Exception {
        mockMvc.perform(get("/products").header(AUTHORIZATION, bearer("ADMIN")))
                .andExpect(status().isOk());
    }

    @Test
    void userIsForbiddenOnTheAttendanceDashboard() throws Exception {
        mockMvc.perform(get("/dashboard/omnichannel").header(AUTHORIZATION, bearer("USER")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    @Test
    void theAttendanceDashboardNeedsAToken() throws Exception {
        mockMvc.perform(get("/dashboard/omnichannel"))
                .andExpect(status().isUnauthorized());
    }
}
