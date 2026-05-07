package com.sevalink.sevalinkbackend.dto;

import com.sevalink.sevalinkbackend.security.UserRole;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class RegisterRequest {
    @NotBlank
    private String name;

    private String email;
    private String phone;

    @NotBlank
    private String password;

    @NotNull
    private UserRole role;
}

