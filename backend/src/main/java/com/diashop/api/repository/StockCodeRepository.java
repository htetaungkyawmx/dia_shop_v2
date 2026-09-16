package com.diashop.api.repository;

import com.diashop.api.domain.StockCode;
import com.diashop.api.domain.StockCodeStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.QueryHints;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface StockCodeRepository extends JpaRepository<StockCode, Long> {

    long countByVariantIdAndStatus(Long variantId, StockCodeStatus status);

    Page<StockCode> findByVariantIdOrderByIdDesc(Long variantId, Pageable pageable);

    boolean existsByVariantIdAndCode(Long variantId, String code);

    List<StockCode> findByOrderItemIdAndStatus(Long orderItemId, StockCodeStatus status);

    /**
     * Claims the next free codes for an order. SKIP LOCKED lets parallel
     * checkouts each take a different code instead of queueing on the same row.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints(@jakarta.persistence.QueryHint(name = "jakarta.persistence.lock.timeout", value = "-2"))
    @Query("""
            SELECT c FROM StockCode c
            WHERE c.variant.id = :variantId AND c.status = 'AVAILABLE'
            ORDER BY c.id ASC
            """)
    List<StockCode> claimAvailable(@Param("variantId") Long variantId, Pageable pageable);

    @Query("""
            SELECT c.variant.id, COUNT(c) FROM StockCode c
            WHERE c.status = 'AVAILABLE' AND c.variant.id IN :variantIds
            GROUP BY c.variant.id
            """)
    List<Object[]> countAvailableByVariantIds(@Param("variantIds") List<Long> variantIds);
}
