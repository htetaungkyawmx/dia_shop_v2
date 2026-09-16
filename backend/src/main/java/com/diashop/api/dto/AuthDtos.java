package com.diashop.api.dto;

import com.diashop.api.domain.Role;
import com.diashop.api.domain.User;
import com.diashop.api.domain.UserStatus;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public final class AuthDtos {

    private AuthDtos() {
    }

    public record RegisterRequest(
            @NotBlank @Email @Size(max = 190) String email,
            @NotBlank @Size(min = 8, max = 72)
            @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).+$",
                    message = "Password must contain at least one letter and one number")
            String password,
            @NotBlank @Size(min = 2, max = 120) String displayName,
            @Size(max = 30) String phone
    ) {
    }

    public record LoginRequest(
            @NotBlank @Email String email,
            @NotBlank String password,
            @Size(max = 255) String deviceInfo
    ) {
    }

    /** Google Sign-In: the app sends the ID token it received from Google. */
    public record GoogleLoginRequest(
            @NotBlank String idToken,
            @Size(max = 255) String deviceInfo
    ) {
    }

    public record RefreshRequest(@NotBlank String refreshToken) {
    }

    public record AuthResponse(
            String accessToken,
            String refreshToken,
            String tokenType,
            long expiresInSeconds,
            UserResponse user
    ) {
        public static AuthResponse of(String access, String refresh, long ttl, UserResponse user) {
            return new AuthResponse(access, refresh, "Bearer", ttl, user);
        }
    }

    public record UserResponse(
            String id,
            String email,
            String displayName,
            String phone,
            String photoUrl,
            Role role,
            UserStatus status,
            String locale,
            long balance,
            Instant createdAt
    ) {
        public static UserResponse of(User user, long balance) {
            return new UserResponse(
                    user.getPublicId().toString(),
                    user.getEmail(),
                    user.getDisplayName(),
                    user.getPhone(),
                    user.getPhotoUrl(),
                    user.getRole(),
                    user.getStatus(),
                    user.getLocale(),
                    balance,
                    user.getCreatedAt());
        }
    }

    public record UpdateProfileRequest(
            @Size(min = 2, max = 120) String displayName,
            @Size(max = 30) String phone,
            @Size(max = 500) String photoUrl,
            @Pattern(regexp = "^(en|my)$", message = "locale must be 'en' or 'my'") String locale
    ) {
    }

    public record ChangePasswordRequest(
            @NotBlank String currentPassword,
            @NotBlank @Size(min = 8, max = 72)
            @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).+$",
                    message = "Password must contain at least one letter and one number")
            String newPassword
    ) {
    }

    public record RegisterDeviceRequest(
            @NotBlank @Size(max = 255) String fcmToken,
            @Pattern(regexp = "^(ANDROID|IOS|WEB)$") String platform
    ) {
    }
}
