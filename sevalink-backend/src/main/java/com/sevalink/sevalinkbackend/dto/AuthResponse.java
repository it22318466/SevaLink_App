package com.sevalink.sevalinkbackend.dto;

import com.sevalink.sevalinkbackend.security.UserRole;
import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class AuthResponse {
    private String token;
    private String tokenType;
    private Long userId;
    private String name;
    private String email;
    private String phone;
    private UserRole role;
}

