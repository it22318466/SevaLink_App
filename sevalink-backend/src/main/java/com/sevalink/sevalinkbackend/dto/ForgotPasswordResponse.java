package com.sevalink.sevalinkbackend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class ForgotPasswordResponse {
    private String message;
    private String resetToken;
}

