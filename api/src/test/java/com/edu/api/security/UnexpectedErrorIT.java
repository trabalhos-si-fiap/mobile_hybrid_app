package com.edu.api.security;

import com.edu.api.auth.service.JwtService;
import com.edu.api.dashboard.service.OmnichannelDashboardService;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.http.HttpHeaders.AUTHORIZATION;

/**
 * Erros que o Spring MVC não trata vão para /error num despacho que não passa
 * pelo filtro do JWT. Precisa de servidor real: o MockMvc não faz esse despacho.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class UnexpectedErrorIT extends OracleIntegrationTest {

    @Value("${local.server.port}")
    private int port;

    @Autowired
    private JwtService jwt;

    @MockitoBean
    private OmnichannelDashboardService omnichannel;

    private HttpResponse<String> get(String path) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header(AUTHORIZATION, "Bearer " + jwt.generateToken(999L, "employee@teste.edu", "EMPLOYEE"))
                .GET()
                .build();
        return HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void anUnhandledExceptionAnswers500AndNot401() throws Exception {
        when(omnichannel.summary(7)).thenThrow(new IllegalStateException("falha inesperada"));

        HttpResponse<String> response = get("/api/v1/dashboard/omnichannel?days=7");

        assertThat(response.statusCode()).isEqualTo(500);
        assertThat(response.body()).doesNotContain("falha inesperada");
    }

    @Test
    void anUnknownRouteAnswers404AndNot401() throws Exception {
        HttpResponse<String> response = get("/api/v1/rota-que-nao-existe");

        assertThat(response.statusCode()).isEqualTo(404);
    }
}
