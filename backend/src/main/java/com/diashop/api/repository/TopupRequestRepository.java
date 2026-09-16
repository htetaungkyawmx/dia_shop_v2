package com.diashop.api.repository;

import com.diashop.api.domain.TopupRequest;
import com.diashop.api.domain.TopupStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface TopupRequestRepository extends JpaRepository<TopupRequest, Long> {

    @EntityGraph(attributePaths = {"user", "paymentMethod"})
    Optional<TopupRequest> findWithDetailsById(Long id);

    @EntityGraph(attributePaths = {"paymentMethod"})
    @Query("""
            SELECT t FROM TopupRequest t
            WHERE t.user.id = :userId
              AND (:status IS NULL OR t.status = :status)
            """)
    Page<TopupRequest> findForUser(@Param("userId") Long userId,
                                   @Param("status") TopupStatus status,
                                   Pageable pageable);

    @EntityGraph(attributePaths = {"user", "paymentMethod"})
    /** @param pattern build with {@link com.diashop.api.common.SearchPattern#of} */
    @Query("""
            SELECT t FROM TopupRequest t
            WHERE (:status IS NULL OR t.status = :status)
              AND (:pattern = '%' OR LOWER(t.requestNo) LIKE :pattern
                                  OR LOWER(t.referenceNo) LIKE :pattern
                                  OR LOWER(t.user.email) LIKE :pattern)
            """)
    Page<TopupRequest> searchForAdmin(@Param("pattern") String pattern,
                                      @Param("status") TopupStatus status,
                                      Pageable pageable);

    long countByStatus(TopupStatus status);

    boolean existsByPaymentMethodIdAndReferenceNoAndStatusIn(Long paymentMethodId,
                                                             String referenceNo,
                                                             List<TopupStatus> statuses);

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM TopupRequest t WHERE t.status = 'APPROVED' AND t.createdAt >= :since")
    long approvedAmountSince(@Param("since") Instant since);
}
