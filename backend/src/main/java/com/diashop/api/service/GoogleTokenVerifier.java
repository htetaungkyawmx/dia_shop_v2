package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.config.AppProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

/**
 * Verifies a Google Sign-In ID token through Google's tokeninfo endpoint,
 * which performs the signature and expiry checks. The audience is additionally
 * checked here against the OAuth client IDs this deployment trusts.
 */
@Slf4j
@Service
public class GoogleTokenVerifier {

    private static final String TOKEN_INFO = "https://oauth2.googleapis.com/tokeninfo";
    private static final List<String> VALID_ISSUERS = List.of("accounts.google.com", "https://accounts.google.com");

    private final RestClient restClient;
    private final List<String> allowedClientIds;

    public GoogleTokenVerifier(AppProperties props, RestClient.Builder builder) {
        this.restClient = builder.baseUrl(TOKEN_INFO).build();
        List<String> ids = props.google() == null ? null : props.google().clientIds();
        this.allowedClientIds = ids == null ? List.of() : ids.stream().filter(s -> !s.isBlank()).toList();
    }

    public record GoogleUser(String subject, String email, String name, String pictureUrl, boolean emailVerified) {
    }

    @SuppressWarnings("unchecked")
    public GoogleUser verify(String idToken) {
        Map<String, Object> payload;
        try {
            payload = restClient.get()
                    .uri(uriBuilder -> uriBuilder.queryParam("id_token", idToken).build())
                    .retrieve()
                    .body(Map.class);
        } catch (Exception e) {
            log.warn("Google token verification call failed: {}", e.getMessage());
            throw ApiException.unauthorized("Could not verify the Google sign-in. Please try again.");
        }
        if (payload == null || payload.get("sub") == null) {
            throw ApiException.unauthorized("That Google sign-in is not valid.");
        }

        String issuer = String.valueOf(payload.get("iss"));
        if (!VALID_ISSUERS.contains(issuer)) {
            throw ApiException.unauthorized("That Google sign-in is not valid.");
        }

        String audience = String.valueOf(payload.get("aud"));
        if (!allowedClientIds.isEmpty() && !allowedClientIds.contains(audience)) {
            log.warn("Rejected Google token for unexpected audience {}", audience);
            throw ApiException.unauthorized("That Google sign-in was issued for a different app.");
        }

        String email = (String) payload.get("email");
        if (email == null || email.isBlank()) {
            throw ApiException.unauthorized("Your Google account did not share an email address.");
        }

        return new GoogleUser(
                (String) payload.get("sub"),
                email,
                (String) payload.getOrDefault("name", email.split("@")[0]),
                (String) payload.get("picture"),
                Boolean.parseBoolean(String.valueOf(payload.getOrDefault("email_verified", "false"))));
    }
}
