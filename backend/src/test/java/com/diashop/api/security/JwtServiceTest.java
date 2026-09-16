package com.diashop.api.security;

import com.diashop.api.config.AppProperties;
import com.diashop.api.domain.Role;
import com.diashop.api.domain.User;
import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {

    private static final String SECRET = "test-secret-that-is-at-least-32-bytes-long";

    private JwtService jwtService;

    @BeforeEach
    void setUp() {
        jwtService = new JwtService(propertiesWith(SECRET, Duration.ofMinutes(30)));
    }

    private AppProperties propertiesWith(String secret, Duration accessTtl) {
        return new AppProperties(
                new AppProperties.Jwt(secret, "dia-shop", accessTtl, Duration.ofDays(30)),
                new AppProperties.Cors(List.of("*")),
                new AppProperties.Storage("local", "./uploads", "http://localhost:8080/uploads"),
                new AppProperties.Admin("admin@test.com", "Admin@12345", "Admin"),
                new AppProperties.Order("DS"),
                new AppProperties.Google(List.of()));
    }

    private User user() {
        User user = new User();
        user.setId(42L);
        user.setPublicId(UUID.randomUUID());
        user.setEmail("buyer@test.com");
        user.setDisplayName("Test Buyer");
        user.setRole(Role.USER);
        return user;
    }

    @Test
    @DisplayName("an access token round-trips the identity claims the filter reads back")
    void accessTokenCarriesIdentity() {
        var claims = jwtService.parse(jwtService.createAccessToken(user()));

        assertThat(claims.getSubject()).isEqualTo("42");
        assertThat(claims.get("email", String.class)).isEqualTo("buyer@test.com");
        assertThat(claims.get("role", String.class)).isEqualTo("USER");
    }

    @Test
    @DisplayName("a token signed with a different secret is rejected")
    void rejectsForeignSignature() {
        var other = new JwtService(propertiesWith("another-secret-that-is-also-32-bytes-ok", Duration.ofMinutes(30)));
        String foreign = other.createAccessToken(user());

        assertThatThrownBy(() -> jwtService.parse(foreign)).isInstanceOf(JwtException.class);
    }

    @Test
    @DisplayName("a tampered payload fails verification")
    void rejectsTamperedToken() {
        String token = jwtService.createAccessToken(user());
        // Flip a character in the payload segment.
        String[] parts = token.split("\\.");
        parts[1] = parts[1].substring(0, parts[1].length() - 2)
                + (parts[1].endsWith("A") ? "B" : "A");
        String tampered = String.join(".", parts);

        assertThatThrownBy(() -> jwtService.parse(tampered)).isInstanceOf(JwtException.class);
    }

    @Test
    @DisplayName("an expired token is rejected")
    void rejectsExpiredToken() {
        var shortLived = new JwtService(propertiesWith(SECRET, Duration.ofSeconds(-1)));
        String expired = shortLived.createAccessToken(user());

        assertThatThrownBy(() -> jwtService.parse(expired)).isInstanceOf(JwtException.class);
    }

    @Test
    @DisplayName("refresh tokens are random and only their hash is comparable")
    void refreshTokensAreRandomAndHashed() {
        String first = jwtService.createRefreshToken();
        String second = jwtService.createRefreshToken();

        assertThat(first).isNotEqualTo(second).hasSizeGreaterThan(32);
        assertThat(jwtService.hashRefreshToken(first))
                .isEqualTo(jwtService.hashRefreshToken(first))
                .isNotEqualTo(jwtService.hashRefreshToken(second))
                .doesNotContain(first);
    }

    @Test
    @DisplayName("a short secret fails fast at startup instead of weakening signing")
    void rejectsShortSecret() {
        assertThatThrownBy(() -> new JwtService(propertiesWith("too-short", Duration.ofMinutes(30))))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("at least 32");
    }
}
