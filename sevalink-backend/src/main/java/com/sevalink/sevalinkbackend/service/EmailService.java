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

    @Autowired(required = false)
    private JavaMailSender mailSender;

    @Value("${spring.mail.username:}")
    private String fromEmail;

    @Value("${app.email.enabled:false}")
    private boolean emailEnabled;

    public void sendPasswordResetEmail(String to, String resetToken) {
        String resetLink = "http://localhost:3000/reset-password?token=" + resetToken;

        // Always log for development
        logger.info("========================================");
        logger.info("📧 PASSWORD RESET REQUEST");
        logger.info("========================================");
        logger.info("To: {}", to);
        logger.info("From: {}", fromEmail);
        logger.info("Email Enabled: {}", emailEnabled);
        logger.info("MailSender Present: {}", mailSender != null);
        logger.info("Reset token: {}", resetToken);
        logger.info("Reset link: {}", resetLink);
        logger.info("========================================");

        // Only send email if configured
        if (emailEnabled && mailSender != null && !fromEmail.isEmpty()) {
            try {
                SimpleMailMessage message = new SimpleMailMessage();
                message.setTo(to);
                message.setSubject("SevaLink - Password Reset Request");
                message.setText(buildEmailBody(resetLink));
                message.setFrom(fromEmail);
                message.setReplyTo(fromEmail);

                logger.info("Attempting to send email...");
                mailSender.send(message);
                logger.info("✅ Email sent successfully to: {}", to);
            } catch (Exception e) {
                logger.error("❌ Failed to send email: {}", e.getMessage());
                e.printStackTrace(); // Print full stack trace
            }
        } else {
            logger.warn("⚠️ Email not sent - Check configuration:");
            if (!emailEnabled) logger.warn("  - Email disabled (app.email.enabled=false)");
            if (mailSender == null) logger.warn("  - MailSender bean not available");
            if (fromEmail.isEmpty()) logger.warn("  - From email not configured");
        }
    }

    private String buildEmailBody(String resetLink) {
        return """
            Hello,
            
            We received a request to reset your password for your SevaLink account.
            
            Click the link below to reset your password:
            %s
            
            This link will expire in 1 hour.
            
            If you didn't request this, please ignore this email.
            
            Best regards,
            SevaLink Team
            """.formatted(resetLink);
    }
}