package com.edu.api.ticket.controller;

import com.edu.api.support.ControllerSliceTest;
import com.edu.api.support.WithAuthenticatedUser;
import com.edu.api.ticket.dto.SegmentResponse;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketQueue;
import com.edu.api.ticket.service.TicketService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ControllerSliceTest(SegmentController.class)
@WithAuthenticatedUser
class SegmentControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private TicketService tickets;

    @Test
    void listsTheActiveSegments() throws Exception {
        when(tickets.segments()).thenReturn(List.of(new SegmentResponse(Segment.DEFEITO_APP,
                "Defeito no App / Problemas com App", TicketQueue.TECNOLOGIA, "Desenvolvedor / Suporte T3", 240)));

        mockMvc.perform(get("/segments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].segment").value("DEFEITO_APP"))
                .andExpect(jsonPath("$[0].queue").value("TECNOLOGIA"));
    }
}
