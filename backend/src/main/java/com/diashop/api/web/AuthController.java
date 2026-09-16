package com.diashop.api.web;

import com.diashop.api.dto.AuthDtos.AuthResponse;
import com.diashop.api.dto.AuthDtos.GoogleLoginRequest;
import com.diashop.api.dto.AuthDtos.LoginRequest;
import com.diashop.api.dto.AuthDtos.RefreshRequest;
import com.diashop.api.dto.AuthDtos.RegisterRequest;
import com.diashop.api.dto.MiscDtos.SimpleMessage;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Auth")
@RestController
@RequestMapping(ApiPaths.API + "/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @Operation(summary = "Create an account with email and password")
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(request));
    }

    @Operation(summary = "Sign in with email and password")
    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @Operation(summary = "Sign in with a Google ID token")
    @PostMapping("/google")
    public AuthResponse google(@Valid @RequestBody GoogleLoginRequest request) {
        return authService.loginWithGoogle(request);
    }

    @Operation(summary = "Exchange a refresh token for a new access token")
    @PostMapping("/refresh")
    public AuthResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return authService.refresh(request.refreshToken());
    }

    @Operation(summary = "Revoke the refresh token for this device")
    @PostMapping("/logout")
    public SimpleMessage logout(@CurrentUser AuthUser principal, @RequestBody(required = false) RefreshRequest request) {
        authService.logout(request == null ? null : request.refreshToken(),
                principal == null ? null : principal.id());
        return SimpleMessage.of("Signed out.");
    }
}
