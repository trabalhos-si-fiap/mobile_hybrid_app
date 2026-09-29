package com.edu.api.employee.controller;

import com.edu.api.employee.dto.EmployeeMeResponse;
import com.edu.api.employee.entity.Presence;
import com.edu.api.employee.service.EmployeeService;
import com.edu.api.security.AuthenticatedUser;
import com.edu.api.support.ControllerSliceTest;
import com.edu.api.support.WithAuthenticatedUser;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ControllerSliceTest(EmployeeController.class)
@WithAuthenticatedUser(id = 2, email = "dev@edu.com", role = "EMPLOYEE")
class EmployeeControllerTest {

    private static final AuthenticatedUser AGENT = new AuthenticatedUser(2L, "dev@edu.com", "EMPLOYEE");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private EmployeeService employees;

    @Test
    void showsTheCurrentAgent() throws Exception {
        when(employees.me(AGENT)).thenReturn(new EmployeeMeResponse(10L, "Diego", Presence.ONLINE,
                Instant.parse("2030-01-01T12:00:00Z"), List.of("DESENVOLVEDOR")));

        mockMvc.perform(get("/employees/me"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.presence").value("ONLINE"))
                .andExpect(jsonPath("$.skills[0]").value("DESENVOLVEDOR"));
    }

    @Test
    void rejectsAnUnknownPresence() throws Exception {
        mockMvc.perform(put("/employees/me/presence")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"presence\":\"DORMINDO\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("BAD_REQUEST"));

        verifyNoInteractions(employees);
    }
}
