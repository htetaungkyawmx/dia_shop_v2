package com.diashop.api.dto;

import com.diashop.api.domain.PaymentMethod;
import com.diashop.api.domain.TopupStatus;
import com.diashop.api.domain.WalletTxType;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public final class WalletDtos {

    private WalletDtos() {
    }

    public record WalletResponse(long balance, long pendingTopupAmount) {
    }

    public record WalletTransactionResponse(
            String id, WalletTxType type, long amount, long balanceAfter,
            String description, String referenceType, Long referenceId, Instant createdAt
    ) {
    }

    public record PaymentMethodResponse(
            Long id, String code, String name, String accountName, String accountNumber,
            String logoUrl, String instructions, String instructionsMy,
            long minAmount, long maxAmount, String gateway
    ) {
        public static PaymentMethodResponse of(PaymentMethod m) {
            return new PaymentMethodResponse(m.getId(), m.getCode(), m.getName(), m.getAccountName(),
                    m.getAccountNumber(), m.getLogoUrl(), m.getInstructions(), m.getInstructionsMy(),
                    m.getMinAmount(), m.getMaxAmount(), m.getGateway());
        }
    }

    public record CreateTopupRequest(
            @NotNull Long paymentMethodId,
            @Min(1) long amount,
            @Size(max = 120) String senderName,
            @Size(max = 30) String senderPhone,
            @NotBlank @Size(max = 80) String referenceNo,
            @Size(max = 500) String screenshotUrl
    ) {
    }

    public record TopupResponse(
            Long id, String requestNo, long amount, TopupStatus status,
            String paymentMethodName, String referenceNo, String senderName, String senderPhone,
            String screenshotUrl, String adminNote,
            Instant createdAt, Instant reviewedAt,
            // admin-only
            String userEmail, String userName, String userId
    ) {
    }

    public record ReviewTopupRequest(
            @Size(max = 500) String adminNote,
            /* when set, credits this amount instead of the requested one */
            Long approvedAmount
    ) {
    }

    public record AdjustBalanceRequest(
            /* positive credits, negative debits */
            @NotNull Long amount,
            @NotBlank @Size(max = 255) String reason
    ) {
    }
}
