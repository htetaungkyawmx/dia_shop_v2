package com.diashop.api.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;
import java.util.List;

@ConfigurationProperties(prefix = "app")
public record AppProperties(
        Jwt jwt,
        Cors cors,
        Storage storage,
        Admin admin,
        Order order,
        Google google
) {
    public record Jwt(String secret, String issuer, Duration accessTokenTtl, Duration refreshTokenTtl) {
    }

    public record Cors(List<String> allowedOrigins) {
    }

    public record Storage(String provider, String localPath, String publicBaseUrl) {
    }

    public record Admin(String email, String password, String displayName) {
    }

    public record Order(String numberPrefix) {
    }

    /** Accepted "aud" values for Google Sign-In ID tokens. Empty disables the check. */
    public record Google(List<String> clientIds) {
    }
}
