package com.sevalink.sevalinkbackend.security;

import com.sevalink.sevalinkbackend.model.User;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

@Getter
public class AuthenticatedUser implements UserDetails {
    private final Long id;
    private final String name;
    private final String email;
    private final String phone;
    private final String password;
    private final UserRole role;
    private final boolean active;

    public AuthenticatedUser(Long id, String name, String email, String phone, String password, UserRole role, boolean active) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.phone = phone;
        this.password = password;
        this.role = role;
        this.active = active;
    }

    public static AuthenticatedUser from(User user) {
        return new AuthenticatedUser(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
                user.getPasswordHash(),
                user.getRole(),
                Boolean.TRUE.equals(user.getIsActive())
        );
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }

    @Override
    public String getUsername() {
        return email != null && !email.isBlank() ? email : phone;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return active;
    }
}

