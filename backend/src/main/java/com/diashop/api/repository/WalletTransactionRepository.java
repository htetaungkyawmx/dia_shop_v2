package com.diashop.api.repository;

import com.diashop.api.domain.WalletTransaction;
import com.diashop.api.domain.WalletTxType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WalletTransactionRepository extends JpaRepository<WalletTransaction, Long> {

    @Query("""
            SELECT t FROM WalletTransaction t
            WHERE t.wallet.user.id = :userId
              AND (:type IS NULL OR t.type = :type)
            ORDER BY t.createdAt DESC, t.id DESC
            """)
    Page<WalletTransaction> findForUser(@Param("userId") Long userId,
                                        @Param("type") WalletTxType type,
                                        Pageable pageable);

    boolean existsByReferenceTypeAndReferenceIdAndType(String referenceType, Long referenceId, WalletTxType type);
}
