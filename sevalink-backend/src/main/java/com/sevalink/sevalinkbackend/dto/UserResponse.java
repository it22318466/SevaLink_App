package com.sevalink.sevalinkbackend.dto;

import com.sevalink.sevalinkbackend.security.UserRole;
import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
public class UserResponse {
    private Long userId;
    private String name;
    private String email;
    private String phone;
    private UserRole role;
    private Boolean phoneVerified;
    private Boolean active;
    private LocalDateTime createdAt;
}

