package com.diashop.api.security;

import com.diashop.api.domain.Role;
import com.diashop.api.domain.User;
import com.diashop.api.domain.UserStatus;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

/** Authenticated principal. Holds only what authorization needs. */
public record AuthUser(Long id, String email, Role role, UserStatus status) implements UserDetails {

    public static AuthUser from(User user) {
        return new AuthUser(user.getId(), user.getEmail(), user.getRole(), user.getStatus());
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        // SUPER_ADMIN implies ADMIN so @PreAuthorize("hasRole('ADMIN')") covers both.
        if (role == Role.SUPER_ADMIN) {
            return List.of(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN"), new SimpleGrantedAuthority("ROLE_ADMIN"));
        }
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }

    @Override
    public String getPassword() {
        return null;
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isEnabled() {
        return status == UserStatus.ACTIVE;
    }

    @Override
    public boolean isAccountNonLocked() {
        return status != UserStatus.SUSPENDED;
    }
}
