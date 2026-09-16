package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.common.SearchPattern;
import com.diashop.api.common.Json;
import com.diashop.api.domain.FulfillmentType;
import com.diashop.api.domain.NotificationType;
import com.diashop.api.domain.Order;
import com.diashop.api.domain.OrderItem;
import com.diashop.api.domain.OrderStatus;
import com.diashop.api.domain.Product;
import com.diashop.api.domain.ProductField;
import com.diashop.api.domain.ProductVariant;
import com.diashop.api.domain.StockCode;
import com.diashop.api.domain.User;
import com.diashop.api.domain.WalletTxType;
import com.diashop.api.dto.OrderDtos.CreateOrderRequest;
import com.diashop.api.dto.OrderDtos.OrderItemRequest;
import com.diashop.api.dto.OrderDtos.OrderItemResponse;
import com.diashop.api.dto.OrderDtos.OrderQuoteResponse;
import com.diashop.api.dto.OrderDtos.OrderResponse;
import com.diashop.api.dto.OrderDtos.QuoteLine;
import com.diashop.api.repository.OrderRepository;
import com.diashop.api.repository.ProductVariantRepository;
import com.diashop.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;

/**
 * Checkout and order lifecycle.
 *
 * Money always moves through {@link WalletService} and stock always moves
 * through {@link StockService}, both inside this single transaction — so an
 * order is never half-paid or half-reserved.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private static final String REF_ORDER = "ORDER";

    private final OrderRepository orderRepository;
    private final ProductVariantRepository variantRepository;
    private final UserRepository userRepository;
    private final WalletService walletService;
    private final StockService stockService;
    private final NotificationService notificationService;
    private final SettingsService settingsService;
    private final CatalogService catalogService;
    private final OrderNumberGenerator numberGenerator;
    private final AuditService auditService;

    // ------------------------------------------------------------- checkout

    @Transactional(readOnly = true)
    public OrderQuoteResponse quote(Long userId, CreateOrderRequest request) {
        long balance = walletService.balanceOf(userId);
        List<QuoteLine> lines = new ArrayList<>();
        long subtotal = 0;

        for (OrderItemRequest item : request.items()) {
            ProductVariant variant = variantRepository.findWithProduct(item.variantId()).orElse(null);
            if (variant == null) {
                lines.add(new QuoteLine(item.variantId(), "-", "Unknown package", 0, item.quantity(), 0,
                        FulfillmentType.MANUAL, false, "This package no longer exists."));
                continue;
            }

            String unavailable = availabilityProblem(variant, item.quantity());
            long lineTotal = variant.getPrice() * item.quantity();
            if (unavailable == null) {
                subtotal += lineTotal;
            }

            lines.add(new QuoteLine(
                    variant.getId(),
                    variant.getProduct().getName(),
                    variant.getName(),
                    variant.getPrice(),
                    item.quantity(),
                    lineTotal,
                    variant.getProduct().getFulfillmentType(),
                    unavailable == null,
                    unavailable));
        }

        boolean allAvailable = lines.stream().allMatch(QuoteLine::available);
        return new OrderQuoteResponse(
                subtotal,
                subtotal,
                balance,
                balance - subtotal,
                allAvailable && balance >= subtotal,
                lines);
    }

    @Transactional
    public OrderResponse create(Long userId, CreateOrderRequest request) {
        if (settingsService.getBoolean(SettingsService.MAINTENANCE, false)) {
            throw new ApiException(org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE, "MAINTENANCE",
                    settingsService.get(SettingsService.MAINTENANCE_MESSAGE,
                            "The shop is temporarily unavailable. Please try again shortly."));
        }
        User user = userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User"));

        Order order = new Order();
        order.setUser(user);
        order.setOrderNo(numberGenerator.nextOrderNo());
        order.setCustomerNote(request.customerNote());
        order.setStatus(OrderStatus.PENDING);

        long subtotal = 0;
        boolean everyItemAutoDelivers = true;

        for (OrderItemRequest itemRequest : request.items()) {
            ProductVariant variant = variantRepository.findWithProduct(itemRequest.variantId())
                    .orElseThrow(() -> ApiException.notFound("Package"));
            Product product = variant.getProduct();

            if (!variant.isActive() || !product.isActive()) {
                throw ApiException.conflict("PACKAGE_UNAVAILABLE",
                        "\"" + variant.getName() + "\" is no longer on sale.");
            }
            if (itemRequest.quantity() > variant.getMaxPerOrder()) {
                throw ApiException.badRequest("QUANTITY_TOO_HIGH",
                        "You can order at most " + variant.getMaxPerOrder() + " of \"" + variant.getName() + "\" at a time.");
            }

            Map<String, String> fieldValues = validateFields(product, itemRequest.fieldValues());

            long lineTotal = variant.getPrice() * itemRequest.quantity();
            subtotal += lineTotal;

            OrderItem item = new OrderItem();
            item.setVariant(variant);
            item.setProductName(product.getName());
            item.setVariantName(variant.getName());
            item.setImageUrl(variant.getImageUrl() != null ? variant.getImageUrl() : product.getImageUrl());
            item.setUnitPrice(variant.getPrice());
            item.setQuantity(itemRequest.quantity());
            item.setLineTotal(lineTotal);
            item.setFieldValues(fieldValues.isEmpty() ? null : Json.write(fieldValues));
            order.addItem(item);

            if (product.getFulfillmentType() != FulfillmentType.CODE_DELIVERY) {
                everyItemAutoDelivers = false;
            }
        }

        order.setSubtotal(subtotal);
        order.setTotal(subtotal);

        // Persist first so the wallet ledger and stock movements can reference
        // the order id. Everything below shares one transaction, so a failure
        // anywhere rolls the whole checkout back.
        Order saved = persistWithUniqueNumber(order);

        walletService.debit(user, subtotal, WalletTxType.PURCHASE,
                "Order " + saved.getOrderNo(), REF_ORDER, saved.getId(), user);

        for (OrderItem item : saved.getItems()) {
            stockService.reserveForSale(item.getVariant().getId(), item.getQuantity(), saved.getId());
        }

        boolean autoDeliver = everyItemAutoDelivers
                && settingsService.getBoolean(SettingsService.AUTO_DELIVER_CODES, true);
        if (autoDeliver) {
            deliverCodes(saved);
            saved.setStatus(OrderStatus.COMPLETED);
            saved.setProcessedAt(Instant.now());
        }
        orderRepository.save(saved);

        notificationService.notify(user, NotificationType.ORDER,
                autoDeliver ? "Order delivered" : "Order received",
                autoDeliver
                        ? "Order " + saved.getOrderNo() + " is complete. Your code is ready to view."
                        : "Order " + saved.getOrderNo() + " is being processed. We will notify you when it is done.",
                Map.of("screen", "order", "orderId", String.valueOf(saved.getId())));

        auditService.record(user, "ORDER_CREATED", "Order", saved.getId(),
                "total=" + subtotal + " items=" + saved.getItems().size());

        return toResponse(saved, false);
    }

    /**
     * Retries once on the (very unlikely) order-number collision rather than
     * failing a checkout that has already been charged.
     */
    private Order persistWithUniqueNumber(Order order) {
        try {
            return orderRepository.saveAndFlush(order);
        } catch (DataIntegrityViolationException e) {
            log.warn("Order number {} collided; regenerating", order.getOrderNo());
            order.setOrderNo(numberGenerator.nextOrderNo());
            return orderRepository.saveAndFlush(order);
        }
    }

    private void deliverCodes(Order order) {
        for (OrderItem item : order.getItems()) {
            ProductVariant variant = item.getVariant();
            List<StockCode> codes = stockService.assignCodes(variant.getId(), item.getQuantity(), item.getId());
            item.setDeliveredCode(String.join("\n", codes.stream().map(StockCode::getCode).toList()));
            item.setDeliveredSecret(codes.get(0).getSecret());
            stockService.syncCodePoolCount(variant);
        }
    }

    // --------------------------------------------------------------- reads

    @Transactional(readOnly = true)
    public Page<OrderResponse> listForUser(Long userId, OrderStatus status, Pageable pageable) {
        return orderRepository.findForUser(userId, status, pageable).map(o -> toResponse(o, false));
    }

    @Transactional(readOnly = true)
    public OrderResponse getForUser(Long userId, Long orderId) {
        Order order = orderRepository.findWithItemsById(orderId)
                .orElseThrow(() -> ApiException.notFound("Order"));
        if (!order.getUser().getId().equals(userId)) {
            throw ApiException.notFound("Order");
        }
        return toResponse(order, false);
    }

    @Transactional(readOnly = true)
    public Page<OrderResponse> searchForAdmin(String query, OrderStatus status, Pageable pageable) {
        return orderRepository.searchForAdmin(SearchPattern.of(query), status, pageable)
                .map(o -> toResponse(o, true));
    }

    @Transactional(readOnly = true)
    public OrderResponse getForAdmin(Long orderId) {
        return toResponse(orderRepository.findWithItemsById(orderId)
                .orElseThrow(() -> ApiException.notFound("Order")), true);
    }

    // ------------------------------------------------------ admin lifecycle

    @Transactional
    public OrderResponse markProcessing(Long orderId, User admin) {
        Order order = loadOpen(orderId);
        if (order.getStatus() != OrderStatus.PENDING) {
            throw ApiException.conflict("INVALID_TRANSITION",
                    "Only a pending order can be moved to processing.");
        }
        order.setStatus(OrderStatus.PROCESSING);
        order.setProcessedBy(admin);
        orderRepository.save(order);

        notificationService.notify(order.getUser(), NotificationType.ORDER,
                "Order in progress",
                "We started working on order " + order.getOrderNo() + ".",
                Map.of("screen", "order", "orderId", String.valueOf(order.getId())));
        auditService.record(admin, "ORDER_PROCESSING", "Order", orderId, null);
        return toResponse(order, true);
    }

    @Transactional
    public OrderResponse complete(Long orderId, String adminNote, User admin) {
        Order order = loadOpen(orderId);
        order.setStatus(OrderStatus.COMPLETED);
        order.setAdminNote(adminNote);
        order.setProcessedBy(admin);
        order.setProcessedAt(Instant.now());

        // Hand over any codes that were not auto-delivered at checkout.
        for (OrderItem item : order.getItems()) {
            ProductVariant variant = item.getVariant();
            if (variant.getStockType() == com.diashop.api.domain.StockType.CODE_POOL
                    && item.getDeliveredCode() == null) {
                List<StockCode> codes = stockService.assignCodes(variant.getId(), item.getQuantity(), item.getId());
                item.setDeliveredCode(String.join("\n", codes.stream().map(StockCode::getCode).toList()));
                item.setDeliveredSecret(codes.get(0).getSecret());
                stockService.syncCodePoolCount(variant);
            }
        }
        orderRepository.save(order);

        notificationService.notify(order.getUser(), NotificationType.ORDER,
                "Order complete",
                "Order " + order.getOrderNo() + " has been delivered. Thank you!",
                Map.of("screen", "order", "orderId", String.valueOf(order.getId())));
        auditService.record(admin, "ORDER_COMPLETED", "Order", orderId, adminNote);
        return toResponse(order, true);
    }

    @Transactional
    public OrderResponse reject(Long orderId, String reason, String adminNote, User admin) {
        Order order = loadOpen(orderId);
        refundAndRelease(order, "Refund for rejected order " + order.getOrderNo(), admin);

        order.setStatus(OrderStatus.REJECTED);
        order.setRejectReason(reason);
        order.setAdminNote(adminNote);
        order.setProcessedBy(admin);
        order.setProcessedAt(Instant.now());
        orderRepository.save(order);

        notificationService.notify(order.getUser(), NotificationType.ORDER,
                "Order rejected",
                "Order " + order.getOrderNo() + " was rejected and " + order.getTotal()
                        + " MMK has been returned to your wallet."
                        + (reason == null || reason.isBlank() ? "" : " Reason: " + reason),
                Map.of("screen", "order", "orderId", String.valueOf(order.getId())));
        auditService.record(admin, "ORDER_REJECTED", "Order", orderId, reason);
        return toResponse(order, true);
    }

    /** Reverses an order that was already completed. */
    @Transactional
    public OrderResponse refund(Long orderId, String adminNote, User admin) {
        Order order = orderRepository.findWithItemsById(orderId)
                .orElseThrow(() -> ApiException.notFound("Order"));
        if (order.getStatus() != OrderStatus.COMPLETED) {
            throw ApiException.conflict("INVALID_TRANSITION", "Only a completed order can be refunded.");
        }
        refundAndRelease(order, "Refund for order " + order.getOrderNo(), admin);

        order.setStatus(OrderStatus.REFUNDED);
        order.setAdminNote(adminNote);
        order.setProcessedBy(admin);
        order.setProcessedAt(Instant.now());
        orderRepository.save(order);

        notificationService.notify(order.getUser(), NotificationType.ORDER,
                "Order refunded",
                order.getTotal() + " MMK for order " + order.getOrderNo() + " has been returned to your wallet.",
                Map.of("screen", "order", "orderId", String.valueOf(order.getId())));
        auditService.record(admin, "ORDER_REFUNDED", "Order", orderId, adminNote);
        return toResponse(order, true);
    }

    @Transactional
    public OrderResponse cancelByUser(Long userId, Long orderId) {
        Order order = orderRepository.findWithItemsById(orderId)
                .orElseThrow(() -> ApiException.notFound("Order"));
        if (!order.getUser().getId().equals(userId)) {
            throw ApiException.notFound("Order");
        }
        if (order.getStatus() != OrderStatus.PENDING) {
            throw ApiException.conflict("CANNOT_CANCEL",
                    "This order is already being processed. Please contact support instead.");
        }
        refundAndRelease(order, "Refund for cancelled order " + order.getOrderNo(), order.getUser());

        order.setStatus(OrderStatus.CANCELLED);
        order.setProcessedAt(Instant.now());
        orderRepository.save(order);

        auditService.record(order.getUser(), "ORDER_CANCELLED", "Order", orderId, null);
        return toResponse(order, false);
    }

    /**
     * Returns the money and the stock exactly once. The wallet ledger is the
     * guard: if a REFUND row already references this order, nothing happens.
     */
    private void refundAndRelease(Order order, String description, User actor) {
        if (walletService.alreadySettled(REF_ORDER, order.getId(), WalletTxType.REFUND)) {
            log.warn("Order {} was already refunded; skipping", order.getOrderNo());
            return;
        }
        walletService.credit(order.getUser(), order.getTotal(), WalletTxType.REFUND,
                description, REF_ORDER, order.getId(), actor);

        for (OrderItem item : order.getItems()) {
            stockService.releaseFromSale(item.getVariant().getId(), item.getQuantity(), order.getId());
            if (item.getDeliveredCode() != null) {
                stockService.voidCodesForOrderItem(item.getId());
                stockService.syncCodePoolCount(item.getVariant());
            }
        }
    }

    private Order loadOpen(Long orderId) {
        Order order = orderRepository.findWithItemsById(orderId)
                .orElseThrow(() -> ApiException.notFound("Order"));
        if (order.isFinal()) {
            throw ApiException.conflict("ORDER_CLOSED",
                    "Order " + order.getOrderNo() + " is already " + order.getStatus().name().toLowerCase() + ".");
        }
        return order;
    }

    // ---------------------------------------------------------- validation

    private Map<String, String> validateFields(Product product, Map<String, String> submitted) {
        Map<String, String> clean = new LinkedHashMap<>();
        Map<String, String> input = submitted == null ? Map.of() : submitted;

        for (ProductField field : product.getFields()) {
            String value = input.get(field.getFieldKey());
            value = value == null ? "" : value.trim();

            if (value.isEmpty()) {
                if (field.isRequired()) {
                    throw ApiException.badRequest("MISSING_FIELD",
                            field.getLabel() + " is required for " + product.getName() + ".");
                }
                continue;
            }
            if (value.length() > 120) {
                throw ApiException.badRequest("FIELD_TOO_LONG", field.getLabel() + " is too long.");
            }
            if (field.getValidationRegex() != null && !field.getValidationRegex().isBlank()) {
                try {
                    if (!Pattern.matches(field.getValidationRegex(), value)) {
                        throw ApiException.badRequest("INVALID_FIELD",
                                field.getLabel() + " does not look right. Please check it and try again.");
                    }
                } catch (PatternSyntaxException e) {
                    log.warn("Product {} field {} has an invalid regex; skipping the check",
                            product.getSlug(), field.getFieldKey());
                }
            }
            if (field.getInputType() == com.diashop.api.domain.FieldInputType.SELECT) {
                List<String> options = catalogService.parseOptions(field.getOptions());
                if (!options.isEmpty() && !options.contains(value)) {
                    throw ApiException.badRequest("INVALID_FIELD",
                            "Please choose a valid option for " + field.getLabel() + ".");
                }
            }
            clean.put(field.getFieldKey(), value);
        }
        return clean;
    }

    private String availabilityProblem(ProductVariant variant, int quantity) {
        if (!variant.isActive() || !variant.getProduct().isActive()) {
            return "This package is no longer on sale.";
        }
        if (quantity > variant.getMaxPerOrder()) {
            return "You can order at most " + variant.getMaxPerOrder() + " at a time.";
        }
        int available = stockService.availableOf(variant);
        if (available < quantity) {
            return available == 0 ? "Out of stock." : "Only " + available + " left.";
        }
        return null;
    }

    // ------------------------------------------------------------- mapping

    OrderResponse toResponse(Order order, boolean includeUser) {
        List<OrderItemResponse> items = order.getItems().stream()
                .map(i -> new OrderItemResponse(
                        i.getId(),
                        i.getVariant().getId(),
                        i.getProductName(),
                        i.getVariantName(),
                        i.getImageUrl(),
                        i.getUnitPrice(),
                        i.getQuantity(),
                        i.getLineTotal(),
                        Json.readStringMap(i.getFieldValues()),
                        i.getDeliveredCode(),
                        i.getDeliveredSecret()))
                .toList();

        return new OrderResponse(
                order.getId(),
                order.getOrderNo(),
                order.getStatus(),
                order.getSubtotal(),
                order.getDiscount(),
                order.getTotal(),
                order.getCustomerNote(),
                order.getAdminNote(),
                order.getRejectReason(),
                items,
                order.getCreatedAt(),
                order.getProcessedAt(),
                includeUser ? order.getUser().getEmail() : null,
                includeUser ? order.getUser().getDisplayName() : null,
                includeUser ? order.getUser().getPublicId().toString() : null);
    }
}
