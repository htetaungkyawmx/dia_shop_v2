package com.diashop.api.service;

import com.diashop.api.common.Json;
import com.diashop.api.domain.Order;
import com.diashop.api.domain.OrderItem;
import com.diashop.api.domain.OrderStatus;
import com.diashop.api.domain.NotificationType;
import com.diashop.api.domain.ProductVariant;
import com.diashop.api.integration.smileone.SmileOneClient;
import com.diashop.api.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * Delivers a paid order through a supplier API when its packages are mapped to
 * one. Runs after checkout has already committed and taken payment, so a
 * provider failure never rolls back the sale: the order simply stays PENDING
 * for staff to finish by hand, exactly like a normal manual order. Safe to call
 * more than once - a line that already has a supplier order id is skipped.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AutoFulfillmentService {

    public static final String SMILEONE = "SMILEONE";

    private final OrderRepository orderRepository;
    private final SmileOneClient smileOne;
    private final NotificationService notificationService;
    private final AuditService auditService;

    /**
     * Best-effort auto delivery. Never throws into the checkout caller. The
     * transaction is committed even when a provider call fails, so any partial
     * progress (a delivered line's supplier order id) is saved rather than lost.
     */
    @Transactional
    public void tryFulfill(Long orderId) {
        try {
            attempt(orderId);
        } catch (Exception e) {
            log.error("Auto-fulfillment crashed for order {}", orderId, e);
        }
    }

    private void attempt(Long orderId) {
        if (!smileOne.isEnabled()) {
            return;
        }
        Order order = orderRepository.findWithItemsById(orderId).orElse(null);
        if (order == null || order.getStatus() != OrderStatus.PENDING) {
            return;
        }

        List<OrderItem> auto = order.getItems().stream().filter(this::isAuto).toList();
        if (auto.isEmpty()) {
            return;
        }

        boolean everythingDelivered = true;
        boolean anyDelivered = false;
        StringBuilder note = new StringBuilder();

        for (OrderItem item : order.getItems()) {
            if (!isAuto(item)) {
                everythingDelivered = false;   // a manual line still needs staff
                continue;
            }
            if (item.getSupplierOrderId() != null) {
                anyDelivered = true;
                continue;                      // already delivered, don't reorder
            }
            ProductVariant variant = item.getVariant();
            String game = variant.getProduct().getSupplierGame();
            Map<String, String> fields = Json.readStringMap(item.getFieldValues());
            String userId = firstOf(fields, "user_id", "player_id", "uid", "userid");
            String zoneId = firstOf(fields, "zone_id", "server_id", "server", "zoneid");

            boolean lineOk = true;
            StringBuilder ids = new StringBuilder();
            for (int i = 0; i < item.getQuantity(); i++) {
                SmileOneClient.Result r = smileOne.createOrder(
                        game, variant.getSupplierProductId(), userId, zoneId);
                if (r.success()) {
                    if (ids.length() > 0) {
                        ids.append(", ");
                    }
                    ids.append(r.orderId() == null ? "ok" : r.orderId());
                } else {
                    lineOk = false;
                    log.warn("Order {} line {} Smile.one failed: {}", order.getOrderNo(),
                            variant.getSku(), r.message());
                    note.append("Smile.one failed for ").append(variant.getName())
                        .append(": ").append(r.message()).append('\n');
                    break;
                }
            }

            if (lineOk) {
                item.setSupplierOrderId(ids.toString());
                item.setDeliveredCode("Smile.one #" + ids);
                anyDelivered = true;
            } else {
                everythingDelivered = false;
            }
        }

        if (everythingDelivered) {
            order.setStatus(OrderStatus.COMPLETED);
            order.setProcessedAt(Instant.now());
            order.setAdminNote("Auto-delivered via Smile.one");
            notificationService.notify(order.getUser(), NotificationType.ORDER,
                    "Order delivered",
                    "Order " + order.getOrderNo() + " has been delivered automatically. Thank you!",
                    Map.of("screen", "order", "orderId", String.valueOf(order.getId())));
            auditService.record(null, "ORDER_AUTO_DELIVERED", "Order", order.getId(), null);
        } else if (note.length() > 0) {
            // Keep the sale open for staff; record why auto delivery stopped.
            order.setAdminNote(note.toString().trim());
            auditService.record(null, "ORDER_AUTO_PARTIAL", "Order", order.getId(),
                    (anyDelivered ? "partial" : "failed"));
        }
        orderRepository.save(order);
    }

    private boolean isAuto(OrderItem item) {
        ProductVariant v = item.getVariant();
        return v != null
                && SMILEONE.equalsIgnoreCase(v.getSupplier())
                && v.getSupplierProductId() != null
                && !v.getSupplierProductId().isBlank();
    }

    private static String firstOf(Map<String, String> fields, String... keys) {
        for (String key : keys) {
            String value = fields.get(key);
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }
}
