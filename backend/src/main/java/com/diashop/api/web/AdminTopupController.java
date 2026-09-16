package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.domain.TopupStatus;
import com.diashop.api.dto.WalletDtos.ReviewTopupRequest;
import com.diashop.api.dto.WalletDtos.TopupResponse;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.TopupService;
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

@Tag(name = "Admin · Top-ups")
@RestController
@RequestMapping(ApiPaths.ADMIN + "/topups")
@RequiredArgsConstructor
public class AdminTopupController {

    private final TopupService topupService;
    private final CurrentUserService currentUserService;

    @GetMapping
    public PageResponse<TopupResponse> list(@RequestParam(required = false) String q,
                                            @RequestParam(required = false) TopupStatus status,
                                            @RequestParam(defaultValue = "0") int page,
                                            @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                topupService.searchForAdmin(q, status, PageRequests.newestFirst(page, size)),
                Function.identity());
    }

    @GetMapping("/{id}")
    public TopupResponse get(@PathVariable Long id) {
        return topupService.getForAdmin(id);
    }

    @Operation(summary = "Confirm the transfer and credit the wallet")
    @PostMapping("/{id}/approve")
    public TopupResponse approve(@CurrentUser AuthUser principal,
                                 @PathVariable Long id,
                                 @Valid @RequestBody(required = false) ReviewTopupRequest request) {
        return topupService.approve(id,
                request == null ? new ReviewTopupRequest(null, null) : request,
                currentUserService.require(principal));
    }

    @PostMapping("/{id}/reject")
    public TopupResponse reject(@CurrentUser AuthUser principal,
                                @PathVariable Long id,
                                @Valid @RequestBody(required = false) ReviewTopupRequest request) {
        return topupService.reject(id,
                request == null ? new ReviewTopupRequest(null, null) : request,
                currentUserService.require(principal));
    }
}
