package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.domain.User;
import com.diashop.api.domain.Wallet;
import com.diashop.api.domain.WalletTransaction;
import com.diashop.api.domain.WalletTxType;
import com.diashop.api.dto.WalletDtos.WalletTransactionResponse;
import com.diashop.api.repository.WalletRepository;
import com.diashop.api.repository.WalletTransactionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * The only component allowed to change a wallet balance.
 *
 * Every change takes a row lock first and writes a ledger row, so the balance
 * is always the sum of wallet_transactions and two concurrent purchases can
 * never both spend the same money.
 */
@Service
@RequiredArgsConstructor
public class WalletService {

    private final WalletRepository walletRepository;
    private final WalletTransactionRepository transactionRepository;

    @Transactional
    public Wallet getOrCreate(User user) {
        return walletRepository.findByUserId(user.getId()).orElseGet(() -> {
            Wallet wallet = new Wallet();
            wallet.setUser(user);
            wallet.setBalance(0L);
            return walletRepository.save(wallet);
        });
    }

    @Transactional(readOnly = true)
    public long balanceOf(Long userId) {
        return walletRepository.findByUserId(userId).map(Wallet::getBalance).orElse(0L);
    }

    /** Adds money. {@code amount} must be positive. */
    @Transactional(propagation = Propagation.MANDATORY)
    public WalletTransaction credit(User user, long amount, WalletTxType type, String description,
                                    String referenceType, Long referenceId, User actor) {
        if (amount <= 0) {
            throw ApiException.badRequest("INVALID_AMOUNT", "Credit amount must be greater than zero.");
        }
        return apply(user, amount, type, description, referenceType, referenceId, actor);
    }

    /** Removes money. {@code amount} must be positive and is subtracted. */
    @Transactional(propagation = Propagation.MANDATORY)
    public WalletTransaction debit(User user, long amount, WalletTxType type, String description,
                                   String referenceType, Long referenceId, User actor) {
        if (amount <= 0) {
            throw ApiException.badRequest("INVALID_AMOUNT", "Debit amount must be greater than zero.");
        }
        return apply(user, -amount, type, description, referenceType, referenceId, actor);
    }

    /**
     * Guards against paying the same source twice — for example an admin
     * double-clicking "approve" on one top-up request.
     */
    @Transactional(readOnly = true)
    public boolean alreadySettled(String referenceType, Long referenceId, WalletTxType type) {
        return transactionRepository.existsByReferenceTypeAndReferenceIdAndType(referenceType, referenceId, type);
    }

    private WalletTransaction apply(User user, long signedAmount, WalletTxType type, String description,
                                    String referenceType, Long referenceId, User actor) {
        Wallet wallet = walletRepository.findByUserIdForUpdate(user.getId())
                .orElseGet(() -> {
                    Wallet fresh = new Wallet();
                    fresh.setUser(user);
                    fresh.setBalance(0L);
                    return walletRepository.saveAndFlush(fresh);
                });

        long newBalance = wallet.getBalance() + signedAmount;
        if (newBalance < 0) {
            throw new ApiException(org.springframework.http.HttpStatus.PAYMENT_REQUIRED,
                    "INSUFFICIENT_BALANCE",
                    "Your balance is not enough. Please top up and try again.");
        }

        wallet.setBalance(newBalance);
        walletRepository.save(wallet);

        WalletTransaction tx = new WalletTransaction();
        tx.setWallet(wallet);
        tx.setType(type);
        tx.setAmount(signedAmount);
        tx.setBalanceAfter(newBalance);
        tx.setDescription(description);
        tx.setReferenceType(referenceType);
        tx.setReferenceId(referenceId);
        tx.setCreatedBy(actor);
        return transactionRepository.save(tx);
    }

    @Transactional(readOnly = true)
    public Page<WalletTransactionResponse> history(Long userId, WalletTxType type, Pageable pageable) {
        return transactionRepository.findForUser(userId, type, pageable).map(WalletService::toResponse);
    }

    public static WalletTransactionResponse toResponse(WalletTransaction tx) {
        return new WalletTransactionResponse(
                tx.getPublicId().toString(),
                tx.getType(),
                tx.getAmount(),
                tx.getBalanceAfter(),
                tx.getDescription(),
                tx.getReferenceType(),
                tx.getReferenceId(),
                tx.getCreatedAt());
    }
}
