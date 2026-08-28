package com.edu.api.auth.dto;

public record AuthResponse(

        String accessToken,

        String tokenType,

        AdminUserResponse user

) {
}