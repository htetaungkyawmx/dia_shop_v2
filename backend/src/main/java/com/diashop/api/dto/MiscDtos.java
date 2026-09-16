package com.diashop.api.dto;

import com.diashop.api.domain.NotificationType;
import com.diashop.api.domain.TicketStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.Map;

public final class MiscDtos {

    private MiscDtos() {
    }

    public record NotificationResponse(
            Long id, String title, String body, NotificationType type,
            Map<String, String> data, boolean read, boolean broadcast, Instant createdAt
    ) {
    }

    public record UnreadCountResponse(long unread) {
    }

    public record CreateTicketRequest(
            @NotBlank @Size(max = 160) String subject,
            @NotBlank @Size(max = 4000) String message,
            Long orderId
    ) {
    }

    public record TicketResponse(
            Long id, String subject, String message, TicketStatus status,
            String adminReply, Instant repliedAt, Instant createdAt,
            String orderNo, String userEmail, String userName
    ) {
    }

    public record UploadResponse(String url, String fileName, long sizeBytes) {
    }

    public record AppConfigResponse(
            String appName,
            boolean maintenance,
            String maintenanceMessage,
            long topupMinAmount,
            long topupMaxAmount,
            Map<String, String> support
    ) {
    }

    public record SimpleMessage(String message) {
        public static SimpleMessage of(String message) {
            return new SimpleMessage(message);
        }
    }
}
