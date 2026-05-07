package com.sevalink.sevalinkbackend.service;

import com.sevalink.sevalinkbackend.dto.*;

public interface AuthService {
    AuthResponse register(RegisterRequest request);
    AuthResponse login(LoginRequest request);
    ForgotPasswordResponse forgotPassword(ForgotPasswordRequest request);
    MessageResponse resetPassword(ResetPasswordRequest request);
    UserResponse getCurrentUser(Long userId);
}


