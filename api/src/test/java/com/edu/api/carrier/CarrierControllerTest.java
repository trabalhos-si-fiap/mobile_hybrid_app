package com.edu.api.carrier;

import com.edu.api.carrier.dto.CarrierRequest;
import com.edu.api.carrier.dto.CarrierResponse;
import com.edu.api.carrier.dto.UpdateCarrierStatusRequest;
import com.edu.api.carrier.entity.CarrierStatus;
import com.edu.api.carrier.service.CarrierService;
import com.edu.api.security.TestSecurityConfig;
import com.fasterxml.jackson.databind.ObjectMapper;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(TestSecurityConfig.class)
class CarrierControllerTest {

    @Autowired
    private MockMvc mockMvc;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @MockitoBean
    private CarrierService carrierService;

    private CarrierRequest validRequest() {

        return new CarrierRequest(
                "Transportadora Teste",
                "São Paulo - SP",
                "transportadora@teste.com",
                5,
                new BigDecimal("4.5"),
                new BigDecimal("95.0"),
                CarrierStatus.ACTIVE
        );
    }

    private CarrierResponse validResponse() {

        return new CarrierResponse(
                1L,
                "Transportadora Teste",
                "São Paulo - SP",
                "transportadora@teste.com",
                5,
                new BigDecimal("4.5"),
                new BigDecimal("95.0"),
                CarrierStatus.ACTIVE,
                Instant.now(),
                Instant.now()
        );
    }

    @Test
    void shouldFindAllCarriers() throws Exception {

        Page<CarrierResponse> page =
                new PageImpl<>(List.of(validResponse()));

        when(carrierService.findAll(
                any(),
                any(),
                any()
        )).thenReturn(page);

        mockMvc.perform(
                get("/carriers")
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldFindCarrierById() throws Exception {

        when(carrierService.findById(1L))
                .thenReturn(validResponse());

        mockMvc.perform(
                get("/carriers/1")
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldCreateCarrier() throws Exception {

        CarrierRequest request = validRequest();

        when(carrierService.create(any(CarrierRequest.class)))
                .thenReturn(validResponse());

        mockMvc.perform(
                post("/carriers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isCreated());
    }

    @Test
    void shouldRejectInvalidCarrier() throws Exception {

        CarrierRequest request = new CarrierRequest(
                "",
                "",
                "email-invalido",
                -1,
                new BigDecimal("6.0"),
                new BigDecimal("101.0"),
                null
        );

        mockMvc.perform(
                post("/carriers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isBadRequest());
    }

    @Test
    void shouldUpdateCarrier() throws Exception {

        CarrierRequest request = validRequest();

        when(carrierService.update(
                eq(1L),
                any(CarrierRequest.class)
        )).thenReturn(validResponse());

        mockMvc.perform(
                put("/carriers/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldUpdateCarrierStatus() throws Exception {

        UpdateCarrierStatusRequest request =
                new UpdateCarrierStatusRequest(
                        CarrierStatus.INACTIVE
                );

        when(carrierService.updateStatus(
                eq(1L),
                any(UpdateCarrierStatusRequest.class)
        )).thenReturn(validResponse());

        mockMvc.perform(
                patch("/carriers/1/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isOk());
    }

    @Test
    void shouldRejectInvalidStatusUpdate() throws Exception {

        UpdateCarrierStatusRequest request =
                new UpdateCarrierStatusRequest(null);

        mockMvc.perform(
                patch("/carriers/1/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
        )
        .andExpect(status().isBadRequest());
    }
}