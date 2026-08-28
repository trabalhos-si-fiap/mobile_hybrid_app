package com.edu.api.auth.dto;

public record AdminUserResponse(

        Long id,
        String name,
        String email,
        String role

) {
}