package com.edu.api.employee.dto;

import com.edu.api.employee.entity.Presence;

import java.time.Instant;
import java.util.List;

public record EmployeeMeResponse(Long id, String name, Presence presence, Instant presenceChangedAt,
                                 List<String> skills) {}
