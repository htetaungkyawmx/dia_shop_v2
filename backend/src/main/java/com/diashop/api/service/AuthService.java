package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.config.AppProperties;
import com.diashop.api.domain.Device;
import com.diashop.api.domain.DevicePlatform;
import com.diashop.api.domain.NotificationType;
import com.diashop.api.domain.RefreshToken;
import com.diashop.api.domain.Role;
import com.diashop.api.domain.User;
import com.diashop.api.domain.UserStatus;
import com.diashop.api.dto.AuthDtos.AuthResponse;
import com.diashop.api.dto.AuthDtos.ChangePasswordRequest;
import com.diashop.api.dto.AuthDtos.GoogleLoginRequest;
import com.diashop.api.dto.AuthDtos.LoginRequest;
import com.diashop.api.dto.AuthDtos.RegisterDeviceRequest;
import com.diashop.api.dto.AuthDtos.RegisterRequest;
import com.diashop.api.dto.AuthDtos.UpdateProfileRequest;
import com.diashop.api.dto.AuthDtos.UserResponse;
import com.diashop.api.repository.DeviceRepository;
import com.diashop.api.repository.RefreshTokenRepository;
import com.diashop.api.repository.UserRepository;
import com.diashop.api.security.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Locale;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final DeviceRepository deviceRepository;
    private final WalletService walletService;
    private final NotificationService notificationService;
    private final GoogleTokenVerifier googleTokenVerifier;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AppProperties props;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = normaliseEmail(request.email());
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw ApiException.conflict("EMAIL_TAKEN", "That email is already registered. Try signing in instead.");
        }

        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setDisplayName(request.displayName().trim());
        user.setPhone(blankToNull(request.phone()));
        user.setRole(Role.USER);
        user.setStatus(UserStatus.ACTIVE);
        user.setLastLoginAt(Instant.now());
        User saved = userRepository.save(user);

        walletService.getOrCreate(saved);
        notificationService.notify(saved, NotificationType.GENERAL,
                "Welcome to Dia Shop",
                "Your account is ready. Top up your wallet to start ordering.",
                Map.of("screen", "home"));

        return issueTokens(saved, null);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        String email = normaliseEmail(request.email());
        User user = userRepository.findByEmailIgnoreCase(email)
                // Same message for unknown email and wrong password, so the
                // endpoint cannot be used to discover which emails exist.
                .orElseThrow(() -> ApiException.unauthorized("Email or password is incorrect."));

        if (user.getPasswordHash() == null) {
            throw ApiException.badRequest("USE_GOOGLE_SIGN_IN",
                    "This account was created with Google. Please continue with Google.");
        }
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw ApiException.unauthorized("Email or password is incorrect.");
        }
        assertUsable(user);

        user.setLastLoginAt(Instant.now());
        walletService.getOrCreate(user);
        return issueTokens(user, request.deviceInfo());
    }

    @Transactional
    public AuthResponse loginWithGoogle(GoogleLoginRequest request) {
        var googleUser = googleTokenVerifier.verify(request.idToken());
        String email = normaliseEmail(googleUser.email());

        User user = userRepository.findByGoogleId(googleUser.subject())
                .or(() -> userRepository.findByEmailIgnoreCase(email))
                .orElseGet(User::new);

        if (user.getId() == null) {
            user.setEmail(email);
            user.setDisplayName(googleUser.name());
            user.setRole(Role.USER);
            user.setStatus(UserStatus.ACTIVE);
        }
        // Link the Google identity to an account that first registered by email.
        user.setGoogleId(googleUser.subject());
        user.setEmailVerified(user.isEmailVerified() || googleUser.emailVerified());
        if (user.getPhotoUrl() == null && googleUser.pictureUrl() != null) {
            user.setPhotoUrl(googleUser.pictureUrl());
        }
        user.setLastLoginAt(Instant.now());
        assertUsable(user);

        User saved = userRepository.save(user);
        walletService.getOrCreate(saved);
        return issueTokens(saved, request.deviceInfo());
    }

    @Transactional
    public AuthResponse refresh(String rawRefreshToken) {
        String hash = jwtService.hashRefreshToken(rawRefreshToken);
        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> ApiException.unauthorized("Your session has expired. Please sign in again."));

        if (!stored.isUsable()) {
            // A revoked token being presented again may mean it was stolen;
            // drop every session for this user and make them sign in fresh.
            refreshTokenRepository.revokeAllForUser(stored.getUser().getId(), Instant.now());
            throw ApiException.unauthorized("Your session has expired. Please sign in again.");
        }

        User user = stored.getUser();
        assertUsable(user);

        // Rotate: the presented token is retired as the new one is issued.
        stored.setRevokedAt(Instant.now());
        refreshTokenRepository.save(stored);
        return issueTokens(user, stored.getDeviceInfo());
    }

    @Transactional
    public void logout(String rawRefreshToken, Long userId) {
        if (rawRefreshToken != null && !rawRefreshToken.isBlank()) {
            refreshTokenRepository.findByTokenHash(jwtService.hashRefreshToken(rawRefreshToken))
                    .filter(t -> t.getUser().getId().equals(userId))
                    .ifPresent(t -> {
                        t.setRevokedAt(Instant.now());
                        refreshTokenRepository.save(t);
                    });
        }
    }

    @Transactional
    public void logoutEverywhere(Long userId) {
        refreshTokenRepository.revokeAllForUser(userId, Instant.now());
    }

    @Transactional(readOnly = true)
    public UserResponse me(Long userId) {
        User user = userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        return UserResponse.of(user, walletService.balanceOf(userId));
    }

    @Transactional
    public UserResponse updateProfile(Long userId, UpdateProfileRequest request) {
        User user = userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        if (request.displayName() != null && !request.displayName().isBlank()) {
            user.setDisplayName(request.displayName().trim());
        }
        if (request.phone() != null) {
            user.setPhone(blankToNull(request.phone()));
        }
        if (request.photoUrl() != null) {
            user.setPhotoUrl(blankToNull(request.photoUrl()));
        }
        if (request.locale() != null) {
            user.setLocale(request.locale());
        }
        return UserResponse.of(userRepository.save(user), walletService.balanceOf(userId));
    }

    @Transactional
    public void changePassword(Long userId, ChangePasswordRequest request) {
        User user = userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        if (user.getPasswordHash() == null) {
            throw ApiException.badRequest("NO_PASSWORD_SET",
                    "This account signs in with Google and has no password.");
        }
        if (!passwordEncoder.matches(request.currentPassword(), user.getPasswordHash())) {
            throw ApiException.badRequest("WRONG_PASSWORD", "Your current password is incorrect.");
        }
        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        userRepository.save(user);

        // Force every other device to sign in again with the new password.
        refreshTokenRepository.revokeAllForUser(userId, Instant.now());
    }

    @Transactional
    public void registerDevice(Long userId, RegisterDeviceRequest request) {
        User user = userRepository.getReferenceById(userId);
        Device device = deviceRepository.findByFcmToken(request.fcmToken()).orElseGet(Device::new);
        device.setUser(user);
        device.setFcmToken(request.fcmToken());
        device.setPlatform(request.platform() == null
                ? DevicePlatform.ANDROID
                : DevicePlatform.valueOf(request.platform()));
        deviceRepository.save(device);
    }

    @Transactional
    public void unregisterDevice(String fcmToken) {
        deviceRepository.deleteByFcmToken(fcmToken);
    }

    /** Keeps refresh_tokens from growing without bound. */
    @Scheduled(cron = "0 30 3 * * *")
    @Transactional
    public void purgeExpiredTokens() {
        int removed = refreshTokenRepository.deleteExpired(Instant.now().minusSeconds(86_400));
        if (removed > 0) {
            log.info("Purged {} expired refresh token(s)", removed);
        }
    }

    private AuthResponse issueTokens(User user, String deviceInfo) {
        String access = jwtService.createAccessToken(user);
        String rawRefresh = jwtService.createRefreshToken();

        RefreshToken token = new RefreshToken();
        token.setUser(user);
        token.setTokenHash(jwtService.hashRefreshToken(rawRefresh));
        token.setDeviceInfo(deviceInfo);
        token.setExpiresAt(jwtService.refreshExpiry());
        refreshTokenRepository.save(token);

        return AuthResponse.of(access, rawRefresh, jwtService.accessTokenSeconds(),
                UserResponse.of(user, walletService.balanceOf(user.getId())));
    }

    private void assertUsable(User user) {
        if (user.getStatus() == UserStatus.SUSPENDED) {
            throw ApiException.forbidden("This account is suspended. Please contact support.");
        }
        if (user.getStatus() == UserStatus.DELETED) {
            throw ApiException.unauthorized("Email or password is incorrect.");
        }
    }

    private String normaliseEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
