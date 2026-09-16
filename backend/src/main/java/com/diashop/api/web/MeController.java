package com.diashop.api.web;

import com.diashop.api.dto.AuthDtos.AccountStatsResponse;
import com.diashop.api.dto.AuthDtos.ChangePasswordRequest;
import com.diashop.api.dto.AuthDtos.RegisterDeviceRequest;
import com.diashop.api.dto.AuthDtos.UpdateProfileRequest;
import com.diashop.api.dto.AuthDtos.UserResponse;
import com.diashop.api.dto.MiscDtos.SimpleMessage;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "My account")
@RestController
@RequestMapping(ApiPaths.API + "/me")
@RequiredArgsConstructor
public class MeController {

    private final AuthService authService;
    private final com.diashop.api.service.StorageService storageService;

    @GetMapping
    public UserResponse me(@CurrentUser AuthUser principal) {
        return authService.me(principal.id());
    }

    @Operation(summary = "Lifetime spend and order counts for the profile screen")
    @GetMapping("/stats")
    public AccountStatsResponse stats(@CurrentUser AuthUser principal) {
        return authService.stats(principal.id());
    }

    @Operation(summary = "Upload a profile photo and set it on the account")
    @PostMapping(value = "/photo", consumes = org.springframework.http.MediaType.MULTIPART_FORM_DATA_VALUE)
    public UserResponse uploadPhoto(@CurrentUser AuthUser principal,
                                    @org.springframework.web.bind.annotation.RequestParam("file")
                                    org.springframework.web.multipart.MultipartFile file) {
        return authService.updatePhoto(principal.id(), storageService.store(file, "avatars"));
    }

    @PatchMapping
    public UserResponse updateProfile(@CurrentUser AuthUser principal,
                                      @Valid @RequestBody UpdateProfileRequest request) {
        return authService.updateProfile(principal.id(), request);
    }

    @Operation(summary = "Change password; all other sessions are signed out")
    @PostMapping("/password")
    public SimpleMessage changePassword(@CurrentUser AuthUser principal,
                                        @Valid @RequestBody ChangePasswordRequest request) {
        authService.changePassword(principal.id(), request);
        return SimpleMessage.of("Password updated. Please sign in again on your other devices.");
    }

    @PostMapping("/devices")
    public SimpleMessage registerDevice(@CurrentUser AuthUser principal,
                                        @Valid @RequestBody RegisterDeviceRequest request) {
        authService.registerDevice(principal.id(), request);
        return SimpleMessage.of("Device registered for notifications.");
    }

    @DeleteMapping("/devices/{token}")
    public SimpleMessage unregisterDevice(@PathVariable String token) {
        authService.unregisterDevice(token);
        return SimpleMessage.of("Device removed.");
    }

    @Operation(summary = "Sign out of every device")
    @PostMapping("/logout-all")
    public SimpleMessage logoutEverywhere(@CurrentUser AuthUser principal) {
        authService.logoutEverywhere(principal.id());
        return SimpleMessage.of("Signed out of all devices.");
    }
}
