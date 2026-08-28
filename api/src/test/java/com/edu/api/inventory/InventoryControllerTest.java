package com.edu.api.inventory;

import com.edu.api.inventory.dto.AdjustInventoryRequest;
import com.edu.api.inventory.dto.InventoryResponse;
import com.edu.api.inventory.service.InventoryService;
import com.edu.api.security.TestSecurityConfig;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.anyBoolean;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.springframework.http.MediaType;

import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(TestSecurityConfig.class)
class InventoryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @MockitoBean
    private InventoryService inventoryService;


    private InventoryResponse validResponse() {

        return new InventoryResponse(
                1L,
                "Produto Teste",
                "EDU-12345678",
                50,
                10,
                "NORMAL"
        );
    }


    @Test
    void shouldFindAllInventory() throws Exception {

        Page<InventoryResponse> page =
                new PageImpl<>(List.of(validResponse()));

        when(inventoryService.findAll(
                any(),
                anyBoolean(),
                any()
        )).thenReturn(page);

        mockMvc.perform(
                get("/inventory")
        )
        .andExpect(status().isOk());
}

    @Test
    void shouldFindLowStockInventory() throws Exception {

        Page<InventoryResponse> page =
                new PageImpl<>(List.of(
                        new InventoryResponse(
                                1L,
                                "Produto Estoque Baixo",
                                "EDU-87654321",
                                5,
                                10,
                                "LOW_STOCK"
                        )
                ));

        when(inventoryService.findAll(
                any(),
                eq(true),
                any()
        )).thenReturn(page);

        mockMvc.perform(
                get("/inventory")
                        .param("lowStock", "true")
        )
        .andExpect(status().isOk());
    }


    @Test
    void shouldAdjustInventory() throws Exception {

        AdjustInventoryRequest request =
                new AdjustInventoryRequest(
                        50,
                        "Reposição de estoque"
                );

        when(inventoryService.adjust(
                eq(1L),
                any(AdjustInventoryRequest.class)
        )).thenReturn(validResponse());

        mockMvc.perform(
                patch("/inventory/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(
                                objectMapper.writeValueAsString(request)
                        )
        )
        .andExpect(status().isOk());
    }


    @Test
    void shouldRejectInvalidInventoryAdjustment() throws Exception {

        AdjustInventoryRequest request =
                new AdjustInventoryRequest(
                        -10,
                        ""
                );

        mockMvc.perform(
                patch("/inventory/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(
                                objectMapper.writeValueAsString(request)
                        )
        )
        .andExpect(status().isBadRequest());
    }
}