package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.common.SearchPattern;
import com.diashop.api.domain.NotificationType;
import com.diashop.api.domain.Role;
import com.diashop.api.domain.User;
import com.diashop.api.domain.UserStatus;
import com.diashop.api.domain.WalletTxType;
import com.diashop.api.dto.AdminDtos.AdminUserResponse;
import com.diashop.api.dto.AdminDtos.CreateStaffRequest;
import com.diashop.api.dto.AdminDtos.UpdateUserRequest;
import com.diashop.api.dto.WalletDtos.AdjustBalanceRequest;
import com.diashop.api.repository.OrderRepository;
import com.diashop.api.repository.RefreshTokenRepository;
import com.diashop.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AdminUserService {

    private final UserRepository userRepository;
    private final OrderRepository orderRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final WalletService walletService;
    private final NotificationService notificationService;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;

    @Transactional(readOnly = true)
    public Page<AdminUserResponse> search(String query, UserStatus status, Role role, Pageable pageable) {
        Page<User> page = userRepository.search(SearchPattern.of(query), status, role, pageable);

        // One aggregate query for the whole page rather than two per row.
        Map<Long, long[]> spend = spendFor(page.getContent().stream().map(User::getId).toList());
        return page.map(u -> toResponse(u, spend.get(u.getId())));
    }

    @Transactional(readOnly = true)
    public AdminUserResponse get(Long id) {
        User user = userRepository.findById(id).orElseThrow(() -> ApiException.notFound("User"));
        return toResponse(user, spendFor(List.of(id)).get(id));
    }

    private Map<Long, long[]> spendFor(List<Long> userIds) {
        if (userIds.isEmpty()) {
            return Map.of();
        }
        Map<Long, long[]> map = new HashMap<>();
        for (Object[] row : orderRepository.spendByUserIds(userIds)) {
            map.put(((Number) row[0]).longValue(),
                    new long[]{((Number) row[1]).longValue(), ((Number) row[2]).longValue()});
        }
        return map;
    }

    @Transactional
    public AdminUserResponse update(Long id, UpdateUserRequest request, User admin) {
        User user = userRepository.findById(id).orElseThrow(() -> ApiException.notFound("User"));

        if (request.displayName() != null && !request.displayName().isBlank()) {
            user.setDisplayName(request.displayName().trim());
        }
        if (request.phone() != null) {
            user.setPhone(request.phone().isBlank() ? null : request.phone().trim());
        }
        if (request.role() != null) {
            Role newRole = Role.valueOf(request.role());
            // Only a SUPER_ADMIN may hand out or take away admin rights.
            if (newRole != user.getRole() && admin.getRole() != Role.SUPER_ADMIN) {
                throw ApiException.forbidden("Only a super admin can change roles.");
            }
            if (user.getId().equals(admin.getId()) && newRole != user.getRole()) {
                throw ApiException.badRequest("CANNOT_CHANGE_OWN_ROLE", "You cannot change your own role.");
            }
            user.setRole(newRole);
        }
        if (request.status() != null) {
            UserStatus newStatus = UserStatus.valueOf(request.status());
            if (user.getId().equals(admin.getId()) && newStatus != UserStatus.ACTIVE) {
                throw ApiException.badRequest("CANNOT_SUSPEND_SELF", "You cannot suspend your own account.");
            }
            if (newStatus != user.getStatus()) {
                user.setStatus(newStatus);
                if (newStatus != UserStatus.ACTIVE) {
                    // Cut off existing sessions immediately.
                    refreshTokenRepository.revokeAllForUser(user.getId(), Instant.now());
                }
            }
        }

        auditService.record(admin, "USER_UPDATED", "User", id,
                "role=" + user.getRole() + " status=" + user.getStatus());
        return toResponse(userRepository.save(user));
    }

    /**
     * Replaces a user's password with a random temporary one, signs them out
     * everywhere and returns the temporary password so staff can pass it on.
     * Used instead of e-mail resets, which need a mail server this shop does
     * not run.
     */
    @Transactional
    public String resetPassword(Long userId, User admin) {
        User user = userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        if (user.isAdmin() && admin.getRole() != Role.SUPER_ADMIN) {
            throw ApiException.forbidden("Only a super admin can reset a staff password.");
        }
        String temporary = TemporaryPassword.generate();
        user.setPasswordHash(passwordEncoder.encode(temporary));
        userRepository.save(user);
        refreshTokenRepository.revokeAllForUser(userId, Instant.now());

        notificationService.notify(user, NotificationType.SYSTEM,
                "Password reset",
                "Your password was reset by support. Sign in with the temporary password you were given, then change it.",
                Map.of("screen", "profile"));
        auditService.record(admin, "PASSWORD_RESET", "User", userId, user.getEmail());
        return temporary;
    }

    @Transactional
    public AdminUserResponse createStaff(CreateStaffRequest request, User admin) {
        if (admin.getRole() != Role.SUPER_ADMIN) {
            throw ApiException.forbidden("Only a super admin can create staff accounts.");
        }
        String email = request.email().trim().toLowerCase(Locale.ROOT);
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw ApiException.conflict("EMAIL_TAKEN", "That email is already registered.");
        }

        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setDisplayName(request.displayName().trim());
        user.setRole(request.role() == null ? Role.ADMIN : Role.valueOf(request.role()));
        user.setStatus(UserStatus.ACTIVE);
        user.setEmailVerified(true);
        User saved = userRepository.save(user);
        walletService.getOrCreate(saved);

        auditService.record(admin, "STAFF_CREATED", "User", saved.getId(), saved.getEmail());
        return toResponse(saved);
    }

    /**
     * Manual balance correction. Goes through the wallet ledger like any other
     * movement, so the adjustment is visible in the customer's history.
     */
    @Transactional
    public AdminUserResponse adjustBalance(Long userId, AdjustBalanceRequest request, User admin) {
        User user = userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        long amount = request.amount();
        if (amount == 0) {
            throw ApiException.badRequest("INVALID_AMOUNT", "Adjustment must not be zero.");
        }

        if (amount > 0) {
            walletService.credit(user, amount, WalletTxType.ADJUSTMENT, request.reason(), "ADJUSTMENT", null, admin);
        } else {
            walletService.debit(user, -amount, WalletTxType.ADJUSTMENT, request.reason(), "ADJUSTMENT", null, admin);
        }

        notificationService.notify(user, NotificationType.SYSTEM,
                amount > 0 ? "Balance added" : "Balance adjusted",
                (amount > 0 ? "+" : "") + amount + " MMK — " + request.reason(),
                Map.of("screen", "wallet"));
        auditService.record(admin, "BALANCE_ADJUSTED", "User", userId,
                "amount=" + amount + " reason=" + request.reason());

        return toResponse(user);
    }

    private AdminUserResponse toResponse(User user) {
        return toResponse(user, spendFor(List.of(user.getId())).get(user.getId()));
    }

    private AdminUserResponse toResponse(User user, long[] spend) {
        long balance = walletService.balanceOf(user.getId());
        long orderCount = spend == null ? 0L : spend[0];
        long totalSpent = spend == null ? 0L : spend[1];
        return new AdminUserResponse(
                user.getId(),
                user.getPublicId().toString(),
                user.getEmail(),
                user.getDisplayName(),
                user.getPhone(),
                user.getPhotoUrl(),
                user.getRole(),
                user.getStatus(),
                balance,
                totalSpent,
                orderCount,
                user.getLastLoginAt(),
                user.getCreatedAt());
    }
}
