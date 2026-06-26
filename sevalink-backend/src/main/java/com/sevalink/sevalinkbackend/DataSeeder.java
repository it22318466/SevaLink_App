package com.sevalink.sevalinkbackend;

import com.sevalink.sevalinkbackend.model.Category;
import com.sevalink.sevalinkbackend.model.User;
import com.sevalink.sevalinkbackend.model.UserRole;
import com.sevalink.sevalinkbackend.repository.CategoryRepository;
import com.sevalink.sevalinkbackend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

@Component
public class DataSeeder implements CommandLineRunner {

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) throws Exception {
        if (categoryRepository.count() == 0) {
            List<String> categories = Arrays.asList(
                    "Electrical",
                    "Plumbing",
                    "Carpentry",
                    "Cleaning",
                    "Painting",
                    "General"
            );

            for (String categoryName : categories) {
                Category category = new Category();
                category.setName(categoryName);
                categoryRepository.save(category);
            }
            System.out.println("Seeded categories into database.");
        }

        if (userRepository.countByRole(UserRole.ADMIN) == 0) {
            User admin = new User();
            admin.setFullName("SevaLink Admin");
            admin.setEmail("admin@sevalink.com");
            admin.setPhoneNumber("+94712345678");
            admin.setPasswordHash(passwordEncoder.encode("Admin@123"));
            admin.setRole(UserRole.ADMIN);
            admin.setBirthday(LocalDate.of(1990, 1, 1));
            admin.setIsPhoneVerified(true);
            admin.setIsEmailVerified(true);
            admin.setIsActive(true);
            admin.setCreatedAt(LocalDateTime.now());
            admin.setUpdatedAt(LocalDateTime.now());
            admin.setProfileImageUrl(null);
            admin.setLocation("Colombo, Sri Lanka");
            userRepository.save(admin);
            System.out.println("Seeded default admin user: admin@sevalink.com / Admin@123");
        }
    }
}
