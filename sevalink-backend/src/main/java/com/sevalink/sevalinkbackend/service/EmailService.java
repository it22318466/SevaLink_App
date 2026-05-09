package com.sevalink.sevalinkbackend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

    private static final Logger logger = LoggerFactory.getLogger(EmailService.class);

    @Autowired(required = false)  // Required = false means emails are optional
    private JavaMailSender mailSender;

    @Value("${spring.mail.username:}")
    private String fromEmail;

    public void sendPasswordResetEmail(String to, String resetToken) {
        String resetLink = "http://localhost:3000/reset-password?token=" + resetToken;
        String emailBody = String.format(
                "Hello,\n\n" +
                        "We received a request to reset your password for your SevaLink account.\n\n" +
                        "Please click the link below to reset your password:\n" +
                        "%s\n\n" +
                        "This link will expire in 1 hour.\n\n" +
                        "If you didn't request this, please ignore this email.\n\n" +
                        "Best regards,\n" +
                        "SevaLink Team",
                resetLink
        );

        // Log the reset link (useful for development)
        logger.info("Password reset requested for: {}", to);
        logger.info("Reset link: {}", resetLink);

        // Send email if mail sender is configured
        if (mailSender != null && !fromEmail.isEmpty()) {
            try {
                SimpleMailMessage message = new SimpleMailMessage();
                message.setTo(to);
                message.setSubject("SevaLink - Password Reset Request");
                message.setText(emailBody);
                message.setFrom(fromEmail);
                mailSender.send(message);
                logger.info("Password reset email sent to: {}", to);
            } catch (Exception e) {
                logger.error("Failed to send email to: {}", to, e);
                throw new RuntimeException("Failed to send reset email. Please try again later.");
            }
        } else {
            // For development: Just log the link
            logger.warn("Email not configured. Reset link for {}: {}", to, resetLink);
        }
    }
}