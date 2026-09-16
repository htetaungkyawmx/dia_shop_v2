package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.common.SearchPattern;
import com.diashop.api.domain.NotificationType;
import com.diashop.api.domain.PaymentMethod;
import com.diashop.api.domain.TopupRequest;
import com.diashop.api.domain.TopupStatus;
import com.diashop.api.domain.User;
import com.diashop.api.domain.WalletTxType;
import com.diashop.api.dto.WalletDtos.CreateTopupRequest;
import com.diashop.api.dto.WalletDtos.PaymentMethodResponse;
import com.diashop.api.dto.WalletDtos.ReviewTopupRequest;
import com.diashop.api.dto.WalletDtos.TopupResponse;
import com.diashop.api.repository.PaymentMethodRepository;
import com.diashop.api.repository.TopupRequestRepository;
import com.diashop.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * Wallet top-ups.
 *
 * Today every method is a manual transfer that an admin verifies from the
 * screenshot. {@link PaymentMethod#getGateway()} is the hook for online
 * gateways later: a method with a gateway set can be auto-approved by the
 * gateway callback instead of a human.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TopupService {

    private static final String REF_TOPUP = "TOPUP";

    private final TopupRequestRepository topupRepository;
    private final PaymentMethodRepository paymentMethodRepository;
    private final UserRepository userRepository;
    private final WalletService walletService;
    private final NotificationService notificationService;
    private final SettingsService settingsService;
    private final OrderNumberGenerator numberGenerator;
    private final AuditService auditService;

    @Transactional(readOnly = true)
    public List<PaymentMethodResponse> activePaymentMethods() {
        return paymentMethodRepository.findByActiveTrueOrderBySortOrderAscIdAsc().stream()
                .map(PaymentMethodResponse::of)
                .toList();
    }

    @Transactional
    public TopupResponse create(Long userId, CreateTopupRequest request) {
        User user = userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        PaymentMethod method = paymentMethodRepository.findById(request.paymentMethodId())
                .filter(PaymentMethod::isActive)
                .orElseThrow(() -> ApiException.notFound("Payment method"));

        long globalMin = settingsService.getLong(SettingsService.TOPUP_MIN, 1000);
        long globalMax = settingsService.getLong(SettingsService.TOPUP_MAX, 5_000_000);
        long min = Math.max(method.getMinAmount(), globalMin);
        long max = Math.min(method.getMaxAmount(), globalMax);

        if (request.amount() < min) {
            throw ApiException.badRequest("AMOUNT_TOO_LOW",
                    "The minimum top-up for " + method.getName() + " is " + min + " MMK.");
        }
        if (request.amount() > max) {
            throw ApiException.badRequest("AMOUNT_TOO_HIGH",
                    "The maximum top-up for " + method.getName() + " is " + max + " MMK.");
        }

        String reference = request.referenceNo().trim();
        // The same transfer reference must not be claimed twice.
        if (topupRepository.existsByPaymentMethodIdAndReferenceNoAndStatusIn(
                method.getId(), reference, List.of(TopupStatus.PENDING, TopupStatus.APPROVED))) {
            throw ApiException.conflict("DUPLICATE_REFERENCE",
                    "That transaction reference has already been submitted.");
        }

        TopupRequest topup = new TopupRequest();
        topup.setRequestNo(numberGenerator.nextTopupNo());
        topup.setUser(user);
        topup.setPaymentMethod(method);
        topup.setAmount(request.amount());
        topup.setSenderName(request.senderName());
        topup.setSenderPhone(request.senderPhone());
        topup.setReferenceNo(reference);
        topup.setScreenshotUrl(request.screenshotUrl());
        topup.setStatus(TopupStatus.PENDING);
        topup.setGateway(method.getGateway());

        TopupRequest saved = topupRepository.save(topup);

        notificationService.notify(user, NotificationType.TOPUP,
                "Top-up submitted",
                "We received your " + request.amount() + " MMK top-up request. "
                        + "It is usually confirmed within a few minutes.",
                Map.of("screen", "wallet", "topupId", String.valueOf(saved.getId())));
        auditService.record(user, "TOPUP_CREATED", "TopupRequest", saved.getId(),
                "amount=" + request.amount() + " method=" + method.getCode());

        return toResponse(saved, false);
    }

    @Transactional
    public TopupResponse cancel(Long userId, Long topupId) {
        TopupRequest topup = topupRepository.findWithDetailsById(topupId)
                .orElseThrow(() -> ApiException.notFound("Top-up request"));
        if (!topup.getUser().getId().equals(userId)) {
            throw ApiException.notFound("Top-up request");
        }
        if (topup.getStatus() != TopupStatus.PENDING) {
            throw ApiException.conflict("CANNOT_CANCEL", "This request has already been reviewed.");
        }
        topup.setStatus(TopupStatus.CANCELLED);
        topup.setReviewedAt(Instant.now());
        return toResponse(topupRepository.save(topup), false);
    }

    @Transactional(readOnly = true)
    public Page<TopupResponse> listForUser(Long userId, TopupStatus status, Pageable pageable) {
        return topupRepository.findForUser(userId, status, pageable).map(t -> toResponse(t, false));
    }

    @Transactional(readOnly = true)
    public Page<TopupResponse> searchForAdmin(String query, TopupStatus status, Pageable pageable) {
        return topupRepository.searchForAdmin(SearchPattern.of(query), status, pageable)
                .map(t -> toResponse(t, true));
    }

    @Transactional(readOnly = true)
    public TopupResponse getForAdmin(Long id) {
        return toResponse(topupRepository.findWithDetailsById(id)
                .orElseThrow(() -> ApiException.notFound("Top-up request")), true);
    }

    @Transactional
    public TopupResponse approve(Long topupId, ReviewTopupRequest request, User admin) {
        TopupRequest topup = topupRepository.findWithDetailsById(topupId)
                .orElseThrow(() -> ApiException.notFound("Top-up request"));
        if (topup.getStatus() != TopupStatus.PENDING) {
            throw ApiException.conflict("ALREADY_REVIEWED",
                    "This request was already " + topup.getStatus().name().toLowerCase() + ".");
        }
        // Belt and braces against a double-click crediting the wallet twice.
        if (walletService.alreadySettled(REF_TOPUP, topup.getId(), WalletTxType.TOPUP)) {
            throw ApiException.conflict("ALREADY_CREDITED", "This top-up has already been credited.");
        }

        // An admin may correct the amount when the screenshot shows a different
        // figure than the customer typed.
        long amount = request.approvedAmount() != null ? request.approvedAmount() : topup.getAmount();
        if (amount <= 0) {
            throw ApiException.badRequest("INVALID_AMOUNT", "Approved amount must be greater than zero.");
        }

        topup.setAmount(amount);
        topup.setStatus(TopupStatus.APPROVED);
        topup.setAdminNote(request.adminNote());
        topup.setReviewedBy(admin);
        topup.setReviewedAt(Instant.now());
        topupRepository.save(topup);

        walletService.credit(topup.getUser(), amount, WalletTxType.TOPUP,
                "Top-up " + topup.getRequestNo() + " via " + topup.getPaymentMethod().getName(),
                REF_TOPUP, topup.getId(), admin);

        notificationService.notify(topup.getUser(), NotificationType.TOPUP,
                "Wallet topped up",
                amount + " MMK has been added to your wallet.",
                Map.of("screen", "wallet", "topupId", String.valueOf(topup.getId())));
        auditService.record(admin, "TOPUP_APPROVED", "TopupRequest", topupId, "amount=" + amount);

        return toResponse(topup, true);
    }

    @Transactional
    public TopupResponse reject(Long topupId, ReviewTopupRequest request, User admin) {
        TopupRequest topup = topupRepository.findWithDetailsById(topupId)
                .orElseThrow(() -> ApiException.notFound("Top-up request"));
        if (topup.getStatus() != TopupStatus.PENDING) {
            throw ApiException.conflict("ALREADY_REVIEWED",
                    "This request was already " + topup.getStatus().name().toLowerCase() + ".");
        }
        topup.setStatus(TopupStatus.REJECTED);
        topup.setAdminNote(request.adminNote());
        topup.setReviewedBy(admin);
        topup.setReviewedAt(Instant.now());
        topupRepository.save(topup);

        notificationService.notify(topup.getUser(), NotificationType.TOPUP,
                "Top-up rejected",
                "Your top-up request " + topup.getRequestNo() + " could not be confirmed."
                        + (request.adminNote() == null || request.adminNote().isBlank()
                            ? " Please contact support."
                            : " Reason: " + request.adminNote()),
                Map.of("screen", "wallet", "topupId", String.valueOf(topup.getId())));
        auditService.record(admin, "TOPUP_REJECTED", "TopupRequest", topupId, request.adminNote());

        return toResponse(topup, true);
    }

    TopupResponse toResponse(TopupRequest t, boolean includeUser) {
        return new TopupResponse(
                t.getId(),
                t.getRequestNo(),
                t.getAmount(),
                t.getStatus(),
                t.getPaymentMethod().getName(),
                t.getReferenceNo(),
                t.getSenderName(),
                t.getSenderPhone(),
                t.getScreenshotUrl(),
                t.getAdminNote(),
                t.getCreatedAt(),
                t.getReviewedAt(),
                includeUser ? t.getUser().getEmail() : null,
                includeUser ? t.getUser().getDisplayName() : null,
                includeUser ? t.getUser().getPublicId().toString() : null);
    }
}
