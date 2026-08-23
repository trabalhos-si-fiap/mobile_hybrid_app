package com.edu.api.occurrence;

import com.edu.api.occurrence.dto.CarrierOccurrenceResponse;
import com.edu.api.occurrence.dto.CreateCarrierOccurrenceRequest;
import com.edu.api.occurrence.dto.UpdateOccurrenceStatusRequest;
import com.edu.api.occurrence.entity.OccurrenceStatus;
import com.edu.api.occurrence.entity.OccurrenceType;
import com.edu.api.occurrence.service.CarrierOccurrenceService;
import com.edu.api.security.TestSecurityConfig;

import com.fasterxml.jackson.databind.ObjectMapper;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(TestSecurityConfig.class)
class CarrierOccurrenceControllerTest {

    @Autowired
    private MockMvc mockMvc;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @MockitoBean
    private CarrierOccurrenceService occurrenceService;

    private CreateCarrierOccurrenceRequest validRequest() {

        return new CreateCarrierOccurrenceRequest(
                1L,
                OccurrenceType.DELIVERY_DELAY,
                "Entrega atrasada"
        );
    }

    private CarrierOccurrenceResponse validResponse() {

        return new CarrierOccurrenceResponse(
                1L,
                1L,
                "Transportadora Teste",
                OccurrenceType.DELIVERY_DELAY,
                "Entrega atrasada",
                OccurrenceStatus.OPEN,
                Instant.now(),
                null
        );
    }

    @Test
    void shouldFindAllOccurrences() throws Exception {

        Page<CarrierOccurrenceResponse> page =
                new PageImpl<>(List.of(validResponse()));

        when(occurrenceService.findAll(
                any(),
                any(),
                any(),
                any()
        )).thenReturn(page);

        mockMvc.perform(
                get("/carrier-occurrences")
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldFindOccurrenceById() throws Exception {

        when(occurrenceService.findById(1L))
                .thenReturn(validResponse());

        mockMvc.perform(
                get("/carrier-occurrences/1")
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldCreateOccurrence() throws Exception {

        CreateCarrierOccurrenceRequest request = validRequest();

        when(occurrenceService.create(
                any(CreateCarrierOccurrenceRequest.class)
        )).thenReturn(validResponse());

        mockMvc.perform(
                post("/carrier-occurrences")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isCreated());
    }

    @Test
    void shouldRejectInvalidOccurrence() throws Exception {

        CreateCarrierOccurrenceRequest request =
                new CreateCarrierOccurrenceRequest(
                        null,
                        null,
                        ""
                );

        mockMvc.perform(
                post("/carrier-occurrences")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isBadRequest());
    }

    @Test
    void shouldUpdateOccurrenceStatus() throws Exception {

        UpdateOccurrenceStatusRequest request =
                new UpdateOccurrenceStatusRequest(
                        OccurrenceStatus.RESOLVED
                );

        when(occurrenceService.updateStatus(
                eq(1L),
                any(UpdateOccurrenceStatusRequest.class)
        )).thenReturn(validResponse());

        mockMvc.perform(
                patch("/carrier-occurrences/1/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldRejectInvalidStatusUpdate() throws Exception {

        UpdateOccurrenceStatusRequest request =
                new UpdateOccurrenceStatusRequest(null);

        mockMvc.perform(
                patch("/carrier-occurrences/1/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isBadRequest());
    }
}