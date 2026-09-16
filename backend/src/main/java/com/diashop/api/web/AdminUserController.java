package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.domain.Role;
import com.diashop.api.domain.TicketStatus;
import com.diashop.api.domain.UserStatus;
import com.diashop.api.domain.WalletTxType;
import com.diashop.api.dto.AdminDtos.AdminUserResponse;
import com.diashop.api.dto.AdminDtos.CreateStaffRequest;
import com.diashop.api.dto.AdminDtos.TicketReplyRequest;
import com.diashop.api.dto.AdminDtos.UpdateUserRequest;
import com.diashop.api.dto.MiscDtos.TicketResponse;
import com.diashop.api.dto.WalletDtos.AdjustBalanceRequest;
import com.diashop.api.dto.WalletDtos.WalletTransactionResponse;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.AdminUserService;
import com.diashop.api.service.SupportService;
import com.diashop.api.service.WalletService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.function.Function;

@Tag(name = "Admin · Users & support")
@RestController
@RequestMapping(ApiPaths.ADMIN)
@RequiredArgsConstructor
public class AdminUserController {

    private final AdminUserService adminUserService;
    private final WalletService walletService;
    private final SupportService supportService;
    private final CurrentUserService currentUserService;

    @GetMapping("/users")
    public PageResponse<AdminUserResponse> users(@RequestParam(required = false) String q,
                                                 @RequestParam(required = false) UserStatus status,
                                                 @RequestParam(required = false) Role role,
                                                 @RequestParam(defaultValue = "0") int page,
                                                 @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                adminUserService.search(q, status, role, PageRequests.newestFirst(page, size)),
                Function.identity());
    }

    @GetMapping("/users/{id}")
    public AdminUserResponse user(@PathVariable Long id) {
        return adminUserService.get(id);
    }

    @PatchMapping("/users/{id}")
    public AdminUserResponse updateUser(@CurrentUser AuthUser principal,
                                        @PathVariable Long id,
                                        @Valid @RequestBody UpdateUserRequest request) {
        return adminUserService.update(id, request, currentUserService.require(principal));
    }

    @Operation(summary = "Create an admin account (super admin only)")
    @PostMapping("/staff")
    public ResponseEntity<AdminUserResponse> createStaff(@CurrentUser AuthUser principal,
                                                         @Valid @RequestBody CreateStaffRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(adminUserService.createStaff(request, currentUserService.require(principal)));
    }

    @Operation(summary = "Credit or debit a wallet manually; the reason is shown to the customer")
    @PostMapping("/users/{id}/balance")
    public AdminUserResponse adjustBalance(@CurrentUser AuthUser principal,
                                           @PathVariable Long id,
                                           @Valid @RequestBody AdjustBalanceRequest request) {
        return adminUserService.adjustBalance(id, request, currentUserService.require(principal));
    }

    @GetMapping("/users/{id}/transactions")
    public PageResponse<WalletTransactionResponse> transactions(@PathVariable Long id,
                                                                @RequestParam(required = false) WalletTxType type,
                                                                @RequestParam(defaultValue = "0") int page,
                                                                @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(walletService.history(id, type, PageRequests.of(page, size)), Function.identity());
    }

    @GetMapping("/tickets")
    public PageResponse<TicketResponse> tickets(@RequestParam(required = false) TicketStatus status,
                                                @RequestParam(defaultValue = "0") int page,
                                                @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                supportService.listForAdmin(status, PageRequests.of(page, size)),
                Function.identity());
    }

    @PostMapping("/tickets/{id}/reply")
    public TicketResponse replyTicket(@CurrentUser AuthUser principal,
                                      @PathVariable Long id,
                                      @Valid @RequestBody TicketReplyRequest request) {
        return supportService.reply(id, request, currentUserService.require(principal));
    }
}
