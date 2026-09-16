package com.diashop.api.dto;

import com.diashop.api.domain.BannerLinkType;
import com.diashop.api.domain.FieldInputType;
import com.diashop.api.domain.FulfillmentType;
import com.diashop.api.domain.Role;
import com.diashop.api.domain.StockMoveReason;
import com.diashop.api.domain.StockType;
import com.diashop.api.domain.TicketStatus;
import com.diashop.api.domain.UserStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;

public final class AdminDtos {

    private AdminDtos() {
    }

    // ------------------------------------------------------------ dashboard
    public record DashboardResponse(
            long pendingOrders, long pendingTopups, long openTickets,
            long totalUsers, long activeUsers, long newUsers7d,
            long revenueToday, long revenue7d, long revenue30d,
            long profit30d, long ordersToday, long orders30d,
            long topups30d, long walletLiability,
            List<DailyPoint> revenueSeries,
            List<TopSeller> topSellers,
            List<LowStockItem> lowStock
    ) {
    }

    public record DailyPoint(String date, long orders, long revenue) {
    }

    public record TopSeller(String productName, String variantName, long quantity, long revenue) {
    }

    public record LowStockItem(Long variantId, String productName, String variantName,
                               int remaining, int threshold, StockType stockType) {
    }

    // ---------------------------------------------------------------- users
    public record AdminUserResponse(
            Long id, String publicId, String email, String displayName, String phone, String photoUrl,
            Role role, UserStatus status, long balance, long totalSpent, long orderCount,
            Instant lastLoginAt, Instant createdAt
    ) {
    }

    public record UpdateUserRequest(
            @Size(min = 2, max = 120) String displayName,
            @Size(max = 30) String phone,
            @Pattern(regexp = "^(USER|ADMIN|SUPER_ADMIN)$") String role,
            @Pattern(regexp = "^(ACTIVE|SUSPENDED|DELETED)$") String status
    ) {
    }

    public record CreateStaffRequest(
            @NotBlank @Email String email,
            @NotBlank @Size(min = 8, max = 72) String password,
            @NotBlank @Size(max = 120) String displayName,
            @Pattern(regexp = "^(ADMIN|SUPER_ADMIN)$") String role
    ) {
    }

    // -------------------------------------------------------------- catalog
    public record CategoryUpsertRequest(
            @NotBlank @Size(max = 80) @Pattern(regexp = "^[a-z0-9-]+$",
                    message = "Slug may contain lowercase letters, numbers and dashes only") String slug,
            @NotBlank @Size(max = 120) String name,
            @Size(max = 120) String nameMy,
            @Size(max = 500) String iconUrl,
            int sortOrder,
            boolean active
    ) {
    }

    public record ProductFieldRequest(
            Long id,
            @NotBlank @Size(max = 50) @Pattern(regexp = "^[a-z0-9_]+$") String key,
            @NotBlank @Size(max = 120) String label,
            @Size(max = 120) String labelMy,
            @Size(max = 160) String placeholder,
            @Size(max = 255) String helpText,
            @NotNull FieldInputType inputType,
            List<String> options,
            @Size(max = 255) String validationRegex,
            boolean required,
            int sortOrder
    ) {
    }

    public record ProductUpsertRequest(
            @NotNull Long categoryId,
            @NotBlank @Size(max = 80) @Pattern(regexp = "^[a-z0-9-]+$") String slug,
            @NotBlank @Size(max = 160) String name,
            @Size(max = 160) String nameMy,
            String description,
            String descriptionMy,
            @Size(max = 500) String imageUrl,
            @Size(max = 500) String bannerUrl,
            String instructions,
            String instructionsMy,
            @NotNull FulfillmentType fulfillmentType,
            boolean featured,
            int sortOrder,
            boolean active,
            @Valid List<ProductFieldRequest> fields
    ) {
    }

    public record VariantUpsertRequest(
            @NotBlank @Size(max = 80) String sku,
            @NotBlank @Size(max = 160) String name,
            @Size(max = 160) String nameMy,
            @Size(max = 80) String bonusText,
            @Size(max = 255) String description,
            @Min(0) long price,
            Long compareAtPrice,
            @Min(0) long costPrice,
            @Size(max = 500) String imageUrl,
            @NotNull StockType stockType,
            /* only applies to LIMITED; ignored otherwise */
            @Min(0) Integer stockQuantity,
            @Min(0) int lowStockThreshold,
            @Min(1) int maxPerOrder,
            @Min(0) int popularity,
            int sortOrder,
            boolean active
    ) {
    }

    // ---------------------------------------------------------------- stock
    public record StockAdjustRequest(
            /* signed: +10 restocks, -3 writes off */
            @NotNull Integer delta,
            @NotNull StockMoveReason reason,
            @Size(max = 255) String note
    ) {
    }

    public record StockSetRequest(
            @NotNull @Min(0) Integer quantity,
            @NotBlank @Size(max = 255) String note
    ) {
    }

    public record StockMovementResponse(
            Long id, Long variantId, int delta, int quantityBefore, int quantityAfter,
            StockMoveReason reason, String note, String actor, Instant createdAt
    ) {
    }

    public record AddStockCodesRequest(
            @NotEmpty List<@NotBlank @Size(max = 255) String> codes,
            /* optional PIN/password shared by all codes in this batch */
            @Size(max = 255) String secret
    ) {
    }

    public record AddStockCodesResponse(int added, int skippedDuplicates, int availableNow) {
    }

    public record StockCodeResponse(
            Long id, String codeMasked, String status, Long orderItemId, Instant assignedAt, Instant createdAt
    ) {
    }

    // -------------------------------------------------------------- content
    public record BannerUpsertRequest(
            @Size(max = 160) String title,
            @NotBlank @Size(max = 500) String imageUrl,
            @NotNull BannerLinkType linkType,
            @Size(max = 255) String linkValue,
            int sortOrder,
            boolean active,
            Instant startsAt,
            Instant endsAt
    ) {
    }

    public record PaymentMethodUpsertRequest(
            @NotBlank @Size(max = 40) String code,
            @NotBlank @Size(max = 120) String name,
            @NotBlank @Size(max = 120) String accountName,
            @NotBlank @Size(max = 80) String accountNumber,
            @Size(max = 500) String logoUrl,
            String instructions,
            String instructionsMy,
            @Min(0) long minAmount,
            @Min(1) long maxAmount,
            int sortOrder,
            boolean active,
            @Size(max = 30) String gateway
    ) {
    }

    public record BroadcastRequest(
            @NotBlank @Size(max = 160) String title,
            @NotBlank @Size(max = 500) String body,
            /* null broadcasts to everyone */
            Long userId
    ) {
    }

    public record SettingUpdateRequest(
            @NotBlank @Size(max = 80) String key,
            @NotNull String value
    ) {
    }

    public record TicketReplyRequest(
            @NotBlank String reply,
            @NotNull TicketStatus status
    ) {
    }

    public record AuditLogResponse(
            Long id, String actor, String action, String entityType, String entityId,
            String detail, Instant createdAt
    ) {
    }
}
