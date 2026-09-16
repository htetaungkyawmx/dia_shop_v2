package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.domain.User;
import com.diashop.api.domain.Wallet;
import com.diashop.api.domain.WalletTransaction;
import com.diashop.api.domain.WalletTxType;
import com.diashop.api.repository.WalletRepository;
import com.diashop.api.repository.WalletTransactionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WalletServiceTest {

    @Mock
    private WalletRepository walletRepository;

    @Mock
    private WalletTransactionRepository transactionRepository;

    private WalletService walletService;
    private User user;
    private Wallet wallet;

    @BeforeEach
    void setUp() {
        walletService = new WalletService(walletRepository, transactionRepository);

        user = new User();
        user.setId(7L);
        user.setEmail("buyer@test.com");
        user.setDisplayName("Buyer");

        wallet = new Wallet();
        wallet.setId(1L);
        wallet.setUser(user);
        wallet.setBalance(20_000L);
    }

    private WalletTransaction captureSavedTransaction() {
        var captor = ArgumentCaptor.forClass(WalletTransaction.class);
        verify(transactionRepository).save(captor.capture());
        return captor.getValue();
    }

    @Test
    @DisplayName("a credit raises the balance and records the running total")
    void creditAddsToBalance() {
        when(walletRepository.findByUserIdForUpdate(7L)).thenReturn(Optional.of(wallet));
        when(transactionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        walletService.credit(user, 50_000L, WalletTxType.TOPUP, "Top-up TP-1", "TOPUP", 3L, user);

        assertThat(wallet.getBalance()).isEqualTo(70_000L);
        WalletTransaction tx = captureSavedTransaction();
        assertThat(tx.getAmount()).isEqualTo(50_000L);
        assertThat(tx.getBalanceAfter()).isEqualTo(70_000L);
        assertThat(tx.getType()).isEqualTo(WalletTxType.TOPUP);
        assertThat(tx.getReferenceType()).isEqualTo("TOPUP");
        assertThat(tx.getReferenceId()).isEqualTo(3L);
    }

    @Test
    @DisplayName("a debit is stored as a negative ledger amount")
    void debitStoresNegativeAmount() {
        when(walletRepository.findByUserIdForUpdate(7L)).thenReturn(Optional.of(wallet));
        when(transactionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        walletService.debit(user, 12_400L, WalletTxType.PURCHASE, "Order DS-1", "ORDER", 9L, user);

        assertThat(wallet.getBalance()).isEqualTo(7_600L);
        WalletTransaction tx = captureSavedTransaction();
        assertThat(tx.getAmount()).isEqualTo(-12_400L);
        assertThat(tx.getBalanceAfter()).isEqualTo(7_600L);
    }

    @Test
    @DisplayName("spending more than the balance is refused and changes nothing")
    void debitBeyondBalanceIsRefused() {
        when(walletRepository.findByUserIdForUpdate(7L)).thenReturn(Optional.of(wallet));

        assertThatThrownBy(() -> walletService.debit(
                user, 20_001L, WalletTxType.PURCHASE, "Order DS-2", "ORDER", 9L, user))
                .isInstanceOf(ApiException.class)
                .satisfies(error -> {
                    ApiException api = (ApiException) error;
                    assertThat(api.getCode()).isEqualTo("INSUFFICIENT_BALANCE");
                    assertThat(api.getStatus()).isEqualTo(HttpStatus.PAYMENT_REQUIRED);
                });

        assertThat(wallet.getBalance()).isEqualTo(20_000L);
        verify(transactionRepository, never()).save(any());
        verify(walletRepository, never()).save(any());
    }

    @Test
    @DisplayName("spending the exact balance is allowed and lands on zero")
    void debitExactBalanceIsAllowed() {
        when(walletRepository.findByUserIdForUpdate(7L)).thenReturn(Optional.of(wallet));
        when(transactionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        walletService.debit(user, 20_000L, WalletTxType.PURCHASE, "Order DS-3", "ORDER", 9L, user);

        assertThat(wallet.getBalance()).isZero();
        assertThat(captureSavedTransaction().getBalanceAfter()).isZero();
    }

    @Test
    @DisplayName("zero and negative amounts are rejected on both sides")
    void rejectsNonPositiveAmounts() {
        assertThatThrownBy(() -> walletService.credit(
                user, 0L, WalletTxType.TOPUP, "bad", null, null, user))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("greater than zero");

        assertThatThrownBy(() -> walletService.debit(
                user, -5L, WalletTxType.PURCHASE, "bad", null, null, user))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("greater than zero");

        verify(walletRepository, never()).findByUserIdForUpdate(any());
    }

    @Test
    @DisplayName("a first-time wallet is created rather than failing the payment")
    void createsWalletOnFirstUse() {
        when(walletRepository.findByUserIdForUpdate(7L)).thenReturn(Optional.empty());
        when(walletRepository.saveAndFlush(any())).thenAnswer(inv -> inv.getArgument(0));
        when(transactionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        walletService.credit(user, 1_000L, WalletTxType.BONUS, "Welcome bonus", null, null, null);

        assertThat(captureSavedTransaction().getBalanceAfter()).isEqualTo(1_000L);
    }
}
