package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.domain.TopupStatus;
import com.diashop.api.domain.WalletTxType;
import com.diashop.api.dto.WalletDtos.CreateTopupRequest;
import com.diashop.api.dto.WalletDtos.PaymentMethodResponse;
import com.diashop.api.dto.WalletDtos.TopupResponse;
import com.diashop.api.dto.WalletDtos.WalletResponse;
import com.diashop.api.dto.WalletDtos.WalletTransactionResponse;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.TopupService;
import com.diashop.api.service.WalletService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.function.Function;

@Tag(name = "Wallet")
@RestController
@RequestMapping(ApiPaths.API + "/wallet")
@RequiredArgsConstructor
public class WalletController {

    private final WalletService walletService;
    private final TopupService topupService;

    @GetMapping
    public WalletResponse wallet(@CurrentUser AuthUser principal) {
        long pending = topupService
                .listForUser(principal.id(), TopupStatus.PENDING, PageRequests.newestFirst(0, 100))
                .getContent().stream()
                .mapToLong(TopupResponse::amount)
                .sum();
        return new WalletResponse(walletService.balanceOf(principal.id()), pending);
    }

    @Operation(summary = "Wallet ledger: top-ups, purchases, refunds and adjustments")
    @GetMapping("/transactions")
    public PageResponse<WalletTransactionResponse> transactions(
            @CurrentUser AuthUser principal,
            @RequestParam(required = false) WalletTxType type,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Page<WalletTransactionResponse> result =
                walletService.history(principal.id(), type, PageRequests.of(page, size));
        return PageResponse.from(result, Function.identity());
    }

    @GetMapping("/payment-methods")
    public List<PaymentMethodResponse> paymentMethods() {
        return topupService.activePaymentMethods();
    }

    @Operation(summary = "Submit a manual transfer for admin verification")
    @PostMapping("/topups")
    public ResponseEntity<TopupResponse> createTopup(@CurrentUser AuthUser principal,
                                                     @Valid @RequestBody CreateTopupRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(topupService.create(principal.id(), request));
    }

    @GetMapping("/topups")
    public PageResponse<TopupResponse> topups(@CurrentUser AuthUser principal,
                                              @RequestParam(required = false) TopupStatus status,
                                              @RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                topupService.listForUser(principal.id(), status, PageRequests.newestFirst(page, size)),
                Function.identity());
    }

    @PostMapping("/topups/{id}/cancel")
    public TopupResponse cancelTopup(@CurrentUser AuthUser principal, @PathVariable Long id) {
        return topupService.cancel(principal.id(), id);
    }
}
