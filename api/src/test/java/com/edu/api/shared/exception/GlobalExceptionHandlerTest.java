package com.edu.api.shared.exception;

import com.edu.api.shared.response.ApiErrorResponse;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();
    private final MockHttpServletRequest request = new MockHttpServletRequest("POST", "/tickets/7/assume");

    @Test
    void conflictBecomes409() {
        ResponseEntity<ApiErrorResponse> response = handler.handleConflict(new ConflictException("em uso"), request);

        assertThat(response.getStatusCode().value()).isEqualTo(409);
        assertThat(response.getBody().error()).isEqualTo("CONFLICT");
        assertThat(response.getBody().message()).isEqualTo("em uso");
    }

    @Test
    void unprocessableBecomes422() {
        ResponseEntity<ApiErrorResponse> response = handler.handleUnprocessable(new UnprocessableException("sem config"), request);

        assertThat(response.getStatusCode().value()).isEqualTo(422);
        assertThat(response.getBody().error()).isEqualTo("UNPROCESSABLE");
    }

    @Test
    void forbiddenBecomes403() {
        ResponseEntity<ApiErrorResponse> response = handler.handleForbidden(new ForbiddenException("não"), request);

        assertThat(response.getStatusCode().value()).isEqualTo(403);
        assertThat(response.getBody().error()).isEqualTo("FORBIDDEN");
    }
}
