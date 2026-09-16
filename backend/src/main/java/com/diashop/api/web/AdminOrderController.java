package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.domain.OrderStatus;
import com.diashop.api.dto.OrderDtos.OrderResponse;
import com.diashop.api.dto.OrderDtos.ProcessOrderRequest;
import com.diashop.api.dto.OrderDtos.RejectOrderRequest;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.AutoFulfillmentService;
import com.diashop.api.service.OrderService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.function.Function;

@Tag(name = "Admin · Orders")
@RestController
@RequestMapping(ApiPaths.ADMIN + "/orders")
@RequiredArgsConstructor
public class AdminOrderController {

    private final OrderService orderService;
    private final AutoFulfillmentService autoFulfillmentService;
    private final CurrentUserService currentUserService;

    @GetMapping
    public PageResponse<OrderResponse> list(@RequestParam(required = false) String q,
                                            @RequestParam(required = false) OrderStatus status,
                                            @RequestParam(defaultValue = "0") int page,
                                            @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                orderService.searchForAdmin(q, status, PageRequests.newestFirst(page, size)),
                Function.identity());
    }

    @GetMapping("/{id}")
    public OrderResponse get(@PathVariable Long id) {
        return orderService.getForAdmin(id);
    }

    @Operation(summary = "Retry auto delivery through the supplier API for this order")
    @PostMapping("/{id}/auto-fulfill")
    public OrderResponse autoFulfill(@PathVariable Long id) {
        autoFulfillmentService.tryFulfill(id);
        return orderService.getForAdmin(id);
    }

    @Operation(summary = "Claim the order so other admins see it is being worked on")
    @PostMapping("/{id}/process")
    public OrderResponse process(@CurrentUser AuthUser principal, @PathVariable Long id) {
        return orderService.markProcessing(id, currentUserService.require(principal));
    }

    @Operation(summary = "Mark delivered; any pending codes are handed to the buyer")
    @PostMapping("/{id}/complete")
    public OrderResponse complete(@CurrentUser AuthUser principal,
                                  @PathVariable Long id,
                                  @Valid @RequestBody(required = false) ProcessOrderRequest request) {
        return orderService.complete(id, request == null ? null : request.adminNote(),
                currentUserService.require(principal));
    }

    @Operation(summary = "Reject and refund the wallet")
    @PostMapping("/{id}/reject")
    public OrderResponse reject(@CurrentUser AuthUser principal,
                                @PathVariable Long id,
                                @Valid @RequestBody RejectOrderRequest request) {
        return orderService.reject(id, request.reason(), request.adminNote(),
                currentUserService.require(principal));
    }

    @Operation(summary = "Refund an order that was already completed")
    @PostMapping("/{id}/refund")
    public OrderResponse refund(@CurrentUser AuthUser principal,
                                @PathVariable Long id,
                                @Valid @RequestBody(required = false) ProcessOrderRequest request) {
        return orderService.refund(id, request == null ? null : request.adminNote(),
                currentUserService.require(principal));
    }
}
