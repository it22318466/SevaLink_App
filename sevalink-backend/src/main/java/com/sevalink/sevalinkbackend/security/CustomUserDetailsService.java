package com.sevalink.sevalinkbackend.security;

import com.sevalink.sevalinkbackend.model.User;
import com.sevalink.sevalinkbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.lang.NonNull;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {
    private final UserRepository userRepository;

    @Override
    public @NonNull UserDetails loadUserByUsername(@NonNull String login) throws UsernameNotFoundException {
        User user = findByLogin(login);
        return AuthenticatedUser.from(user);
    }

    private User findByLogin(String login) {
        String normalized = login.trim();
        if (normalized.contains("@")) {
            return userRepository.findByEmail(normalized.toLowerCase())
                    .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        }
        if (StringUtils.hasText(normalized)) {
            return userRepository.findByPhone(normalized)
                    .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        }
        throw new UsernameNotFoundException("User not found");
    }
}


