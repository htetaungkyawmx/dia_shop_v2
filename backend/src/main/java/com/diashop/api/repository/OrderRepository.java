package com.diashop.api.repository;

import com.diashop.api.domain.Order;
import com.diashop.api.domain.OrderStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;

public interface OrderRepository extends JpaRepository<Order, Long> {

    @EntityGraph(attributePaths = {"items", "user"})
    Optional<Order> findByOrderNo(String orderNo);

    @EntityGraph(attributePaths = {"items", "user"})
    Optional<Order> findWithItemsById(Long id);

    @EntityGraph(attributePaths = {"items"})
    @Query("""
            SELECT o FROM Order o
            WHERE o.user.id = :userId
              AND (:status IS NULL OR o.status = :status)
            """)
    Page<Order> findForUser(@Param("userId") Long userId,
                            @Param("status") OrderStatus status,
                            Pageable pageable);

    @EntityGraph(attributePaths = {"items", "user"})
    /** @param pattern build with {@link com.diashop.api.common.SearchPattern#of} */
    @Query("""
            SELECT o FROM Order o
            WHERE (:status IS NULL OR o.status = :status)
              AND (:pattern = '%' OR LOWER(o.orderNo) LIKE :pattern
                                  OR LOWER(o.user.email) LIKE :pattern
                                  OR LOWER(o.user.displayName) LIKE :pattern)
            """)
    Page<Order> searchForAdmin(@Param("pattern") String pattern,
                               @Param("status") OrderStatus status,
                               Pageable pageable);

    long countByStatus(OrderStatus status);

    /** [userId, completedOrders, totalSpent] for a page of users, in one query. */
    @Query("""
            SELECT o.user.id, COUNT(o), COALESCE(SUM(o.total), 0)
            FROM Order o
            WHERE o.status = 'COMPLETED' AND o.user.id IN :userIds
            GROUP BY o.user.id
            """)
    java.util.List<Object[]> spendByUserIds(@Param("userIds") java.util.List<Long> userIds);

    @Query("SELECT COUNT(o) FROM Order o WHERE o.createdAt >= :since")
    long countSince(@Param("since") Instant since);

    @Query("SELECT COALESCE(SUM(o.total), 0) FROM Order o WHERE o.status = 'COMPLETED' AND o.createdAt >= :since")
    long revenueSince(@Param("since") Instant since);

    @Query("""
            SELECT COALESCE(SUM(i.lineTotal - (i.variant.costPrice * i.quantity)), 0)
            FROM Order o JOIN o.items i
            WHERE o.status = 'COMPLETED' AND o.createdAt >= :since
            """)
    long profitSince(@Param("since") Instant since);

    @Query(value = """
            SELECT to_char(d.day, 'YYYY-MM-DD') AS day,
                   COALESCE(COUNT(o.id), 0)     AS orders,
                   COALESCE(SUM(o.total), 0)    AS revenue
            FROM generate_series(CAST(:since AS date), CURRENT_DATE, '1 day') AS d(day)
            LEFT JOIN orders o
                   ON CAST(o.created_at AS date) = d.day
                  AND o.status = 'COMPLETED'
            GROUP BY d.day
            ORDER BY d.day
            """, nativeQuery = true)
    java.util.List<Object[]> dailyRevenue(@Param("since") java.time.LocalDate since);

    @Query("""
            SELECT i.productName, i.variantName, SUM(i.quantity), SUM(i.lineTotal)
            FROM Order o JOIN o.items i
            WHERE o.status = 'COMPLETED' AND o.createdAt >= :since
            GROUP BY i.productName, i.variantName
            ORDER BY SUM(i.lineTotal) DESC
            """)
    java.util.List<Object[]> topSellers(@Param("since") Instant since, Pageable pageable);
}
