package com.diashop.api.repository;

import com.diashop.api.domain.ProductVariant;
import com.diashop.api.domain.StockType;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ProductVariantRepository extends JpaRepository<ProductVariant, Long> {

    List<ProductVariant> findByProductIdOrderBySortOrderAscIdAsc(Long productId);

    Optional<ProductVariant> findBySku(String sku);

    boolean existsBySku(String sku);

    /** Locked before decrementing stock so two buyers cannot take the last unit. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT v FROM ProductVariant v WHERE v.id = :id")
    Optional<ProductVariant> findByIdForUpdate(@Param("id") Long id);

    @Query("""
            SELECT v FROM ProductVariant v
            WHERE v.stockType = :stockType
              AND v.active = TRUE
              AND v.stockQuantity <= v.lowStockThreshold
            ORDER BY v.stockQuantity ASC
            """)
    List<ProductVariant> findLowStock(@Param("stockType") StockType stockType);

    @Query("SELECT v FROM ProductVariant v JOIN FETCH v.product WHERE v.id = :id")
    Optional<ProductVariant> findWithProduct(@Param("id") Long id);
}
