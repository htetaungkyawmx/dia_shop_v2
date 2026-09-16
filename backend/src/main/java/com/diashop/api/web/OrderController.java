package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.domain.OrderStatus;
import com.diashop.api.dto.OrderDtos.CreateOrderRequest;
import com.diashop.api.dto.OrderDtos.OrderQuoteResponse;
import com.diashop.api.dto.OrderDtos.OrderResponse;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.AutoFulfillmentService;
import com.diashop.api.service.OrderService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.function.Function;

@Tag(name = "Orders")
@RestController
@RequestMapping(ApiPaths.API + "/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;
    private final AutoFulfillmentService autoFulfillmentService;

    @Operation(summary = "Price a basket and check stock without placing the order")
    @PostMapping("/quote")
    public OrderQuoteResponse quote(@CurrentUser AuthUser principal,
                                    @Valid @RequestBody CreateOrderRequest request) {
        return orderService.quote(principal.id(), request);
    }

    @Operation(summary = "Place an order, paid from the wallet balance")
    @PostMapping
    public ResponseEntity<OrderResponse> create(@CurrentUser AuthUser principal,
                                                @Valid @RequestBody CreateOrderRequest request) {
        OrderResponse created = orderService.create(principal.id(), request);
        // Payment is already taken and committed. Try to deliver mapped
        // packages through the supplier API; on any problem the order simply
        // stays pending for staff. Re-read so the customer sees the final state.
        autoFulfillmentService.tryFulfill(created.id());
        OrderResponse result = orderService.getForUser(principal.id(), created.id());
        return ResponseEntity.status(HttpStatus.CREATED).body(result);
    }

    @GetMapping
    public PageResponse<OrderResponse> list(@CurrentUser AuthUser principal,
                                            @RequestParam(required = false) OrderStatus status,
                                            @RequestParam(defaultValue = "0") int page,
                                            @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                orderService.listForUser(principal.id(), status, PageRequests.newestFirst(page, size)),
                Function.identity());
    }

    @GetMapping("/{id}")
    public OrderResponse get(@CurrentUser AuthUser principal, @PathVariable Long id) {
        return orderService.getForUser(principal.id(), id);
    }

    @Operation(summary = "Cancel an order that has not been picked up yet; the wallet is refunded")
    @PostMapping("/{id}/cancel")
    public OrderResponse cancel(@CurrentUser AuthUser principal, @PathVariable Long id) {
        return orderService.cancelByUser(principal.id(), id);
    }
}
