package com.diashop.api.dto;

import com.diashop.api.domain.FulfillmentType;
import com.diashop.api.domain.OrderStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class OrderDtos {

    private OrderDtos() {
    }

    public record OrderItemRequest(
            @NotNull Long variantId,
            @Min(1) @Max(100) int quantity,
            /* answers keyed by ProductField.fieldKey */
            Map<String, String> fieldValues
    ) {
    }

    public record CreateOrderRequest(
            @NotEmpty @Valid List<OrderItemRequest> items,
            @Size(max = 500) String customerNote
    ) {
    }

    public record OrderItemResponse(
            Long id, Long variantId, String productSlug, String productName, String variantName, String imageUrl,
            long unitPrice, int quantity, long lineTotal,
            Map<String, String> fieldValues,
            String deliveredCode, String deliveredSecret
    ) {
    }

    public record OrderResponse(
            Long id, String orderNo, OrderStatus status,
            long subtotal, long discount, long total,
            String customerNote, String adminNote, String rejectReason,
            List<OrderItemResponse> items,
            Instant createdAt, Instant processedAt,
            // admin-only fields, null in user responses
            String userEmail, String userName, String userId
    ) {
    }

    /** Checkout preview so the app can show the total before committing. */
    public record OrderQuoteResponse(
            long subtotal, long total, long walletBalance, long balanceAfter,
            boolean affordable, List<QuoteLine> lines
    ) {
    }

    public record QuoteLine(
            Long variantId, String productName, String variantName,
            long unitPrice, int quantity, long lineTotal,
            FulfillmentType fulfillmentType, boolean available, String unavailableReason
    ) {
    }

    public record ProcessOrderRequest(
            @Size(max = 500) String adminNote
    ) {
    }

    public record RejectOrderRequest(
            @Size(max = 255) String reason,
            @Size(max = 500) String adminNote
    ) {
    }
}
