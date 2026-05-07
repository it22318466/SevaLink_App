package com.sevalink.sevalinkbackend.service;

import com.sevalink.sevalinkbackend.dto.*;
import com.sevalink.sevalinkbackend.model.User;
import com.sevalink.sevalinkbackend.repository.UserRepository;
import com.sevalink.sevalinkbackend.security.AuthenticatedUser;
import com.sevalink.sevalinkbackend.security.JwtTokenProvider;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.data.redis.core.StringRedisTemplate;

import java.time.Duration;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional
public class AuthServiceImpl implements AuthService {
    private static final Logger log = LoggerFactory.getLogger(AuthServiceImpl.class);
    private static final String RESET_PREFIX = "password-reset:";
    private static final Duration RESET_TOKEN_TTL = Duration.ofMinutes(15);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider jwtTokenProvider;
    private final JavaMailSender mailSender;
    private final StringRedisTemplate stringRedisTemplate;

    @Override
    public AuthResponse register(RegisterRequest request) {
        validateRegistrationRequest(request);

        if (StringUtils.hasText(request.getEmail()) && userRepository.existsByEmail(request.getEmail().trim().toLowerCase())) {
            throw new IllegalArgumentException("Email already exists");
        }
        if (StringUtils.hasText(request.getPhone()) && userRepository.existsByPhone(request.getPhone().trim())) {
            throw new IllegalArgumentException("Phone already exists");
        }

        User user = new User();
        user.setName(request.getName().trim());
        user.setEmail(normalizeToNull(request.getEmail()));
        user.setPhone(normalizeToNull(request.getPhone()));
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setRole(request.getRole());
        user.setIsActive(true);
        user.setIsPhoneVerified(false);

        user = userRepository.save(user);
        String token = jwtTokenProvider.generateToken(AuthenticatedUser.from(user));
        return toAuthResponse(user, token);
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        UsernamePasswordAuthenticationToken authenticationToken =
                new UsernamePasswordAuthenticationToken(request.getLogin().trim(), request.getPassword());
        var authentication = authenticationManager.authenticate(authenticationToken);
        AuthenticatedUser principal = (AuthenticatedUser) authentication.getPrincipal();
        String token = jwtTokenProvider.generateToken(principal);
        return toAuthResponse(principal, token);
    }

    @Override
    public ForgotPasswordResponse forgotPassword(ForgotPasswordRequest request) {
        User user = findUserByLogin(request.getLogin());
        String token = UUID.randomUUID().toString().replace("-", "");
        stringRedisTemplate.opsForValue().set(RESET_PREFIX + token, user.getEmail() != null ? user.getEmail() : user.getPhone(), RESET_TOKEN_TTL);

        try {
            sendResetEmail(user, token);
        } catch (Exception ex) {
            log.warn("Failed to send reset email for {}: {}", request.getLogin(), ex.getMessage());
        }

        return new ForgotPasswordResponse("Password reset token created", token);
    }

    @Override
    public MessageResponse resetPassword(ResetPasswordRequest request) {
        String key = RESET_PREFIX + request.getToken();
        String login = stringRedisTemplate.opsForValue().get(key);
        if (login == null) {
            throw new IllegalArgumentException("Reset token is invalid or expired");
        }

        User user = findUserByLogin(login);
        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
        stringRedisTemplate.delete(key);

        return new MessageResponse("Password updated successfully");
    }

    @Override
    public UserResponse getCurrentUser(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        return new UserResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
                user.getRole(),
                user.getIsPhoneVerified(),
                user.getIsActive(),
                user.getCreatedAt()
        );
    }

    private void validateRegistrationRequest(RegisterRequest request) {
        if (!StringUtils.hasText(request.getEmail()) && !StringUtils.hasText(request.getPhone())) {
            throw new IllegalArgumentException("Either email or phone is required");
        }
        if (!StringUtils.hasText(request.getName())) {
            throw new IllegalArgumentException("Name is required");
        }
        if (!StringUtils.hasText(request.getPassword())) {
            throw new IllegalArgumentException("Password is required");
        }
    }

    private User findUserByLogin(String login) {
        String normalized = login.trim();
        return normalized.contains("@")
                ? userRepository.findByEmail(normalized.toLowerCase())
                    .orElseThrow(() -> new IllegalArgumentException("User not found"))
                : userRepository.findByPhone(normalized)
                    .orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

    private String normalizeToNull(String value) {
        return StringUtils.hasText(value) ? value.trim().toLowerCase() : null;
    }

    private AuthResponse toAuthResponse(User user, String token) {
        return new AuthResponse(
                token,
                "Bearer",
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
                user.getRole()
        );
    }

    private AuthResponse toAuthResponse(AuthenticatedUser user, String token) {
        return new AuthResponse(
                token,
                "Bearer",
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
                user.getRole()
        );
    }

    private void sendResetEmail(User user, String token) {
        String recipient = user.getEmail();
        if (!StringUtils.hasText(recipient)) {
            return;
        }

        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(recipient);
        message.setSubject("SevaLink password reset");
        message.setText("Your password reset token is: " + token + "\nIt expires in 15 minutes.");
        mailSender.send(message);
    }
}


