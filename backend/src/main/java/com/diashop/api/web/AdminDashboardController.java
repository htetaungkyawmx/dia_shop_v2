package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.dto.AdminDtos.AuditLogResponse;
import com.diashop.api.dto.AdminDtos.BroadcastRequest;
import com.diashop.api.dto.AdminDtos.DashboardResponse;
import com.diashop.api.dto.AdminDtos.SettingUpdateRequest;
import com.diashop.api.dto.MiscDtos.SimpleMessage;
import com.diashop.api.dto.MiscDtos.UploadResponse;
import com.diashop.api.domain.NotificationType;
import com.diashop.api.repository.AuditLogRepository;
import com.diashop.api.repository.UserRepository;
import com.diashop.api.service.DashboardService;
import com.diashop.api.service.NotificationService;
import com.diashop.api.service.SettingsService;
import com.diashop.api.service.StorageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@Tag(name = "Admin · Dashboard")
@RestController
@RequestMapping(ApiPaths.ADMIN)
@RequiredArgsConstructor
public class AdminDashboardController {

    private final DashboardService dashboardService;
    private final SettingsService settingsService;
    private final NotificationService notificationService;
    private final AuditLogRepository auditLogRepository;
    private final UserRepository userRepository;
    private final StorageService storageService;

    @Operation(summary = "Counts, revenue, 30-day series, top sellers and low stock")
    @GetMapping("/dashboard")
    public DashboardResponse dashboard() {
        return dashboardService.load();
    }

    @GetMapping("/settings")
    public Map<String, String> settings() {
        return settingsService.all();
    }

    @PutMapping("/settings")
    public Map<String, String> updateSetting(@Valid @RequestBody SettingUpdateRequest request) {
        settingsService.put(request.key(), request.value());
        return settingsService.all();
    }

    @Operation(summary = "Send a notification to one user, or to everyone when userId is omitted")
    @PostMapping("/notifications")
    public SimpleMessage broadcast(@Valid @RequestBody BroadcastRequest request) {
        if (request.userId() == null) {
            notificationService.broadcast(NotificationType.PROMOTION, request.title(), request.body(), Map.of());
            return SimpleMessage.of("Sent to all users.");
        }
        var user = userRepository.findById(request.userId())
                .orElseThrow(() -> com.diashop.api.common.ApiException.notFound("User"));
        notificationService.notify(user, NotificationType.GENERAL, request.title(), request.body(), Map.of());
        return SimpleMessage.of("Sent to " + user.getEmail() + ".");
    }

    @GetMapping("/audit-logs")
    public PageResponse<AuditLogResponse> auditLogs(@RequestParam(defaultValue = "0") int page,
                                                    @RequestParam(defaultValue = "30") int size) {
        return PageResponse.from(
                auditLogRepository.findAllByOrderByCreatedAtDesc(PageRequests.of(page, size)),
                log -> new AuditLogResponse(
                        log.getId(),
                        log.getActor() == null ? "system" : log.getActor().getDisplayName(),
                        log.getAction(),
                        log.getEntityType(),
                        log.getEntityId(),
                        log.getDetail(),
                        log.getCreatedAt()));
    }

    @Operation(summary = "Upload a product, banner or category image")
    @PostMapping(value = "/uploads/image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public UploadResponse uploadImage(@RequestParam("file") MultipartFile file,
                                      @RequestParam(defaultValue = "catalog") String folder) {
        String url = storageService.store(file, folder);
        return new UploadResponse(url, file.getOriginalFilename(), file.getSize());
    }
}
