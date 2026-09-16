package com.diashop.api.repository;

import com.diashop.api.domain.Product;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ProductRepository extends JpaRepository<Product, Long> {

    @EntityGraph(attributePaths = {"category"})
    Optional<Product> findBySlug(String slug);

    boolean existsBySlug(String slug);

    @EntityGraph(attributePaths = {"category"})
    List<Product> findByActiveTrueAndFeaturedTrueOrderBySortOrderAscIdAsc();

    /**
     * @param categorySlug blank means every category
     * @param pattern      build with {@link com.diashop.api.common.SearchPattern#of}
     */
    @Query("""
            SELECT p FROM Product p
            WHERE p.active = TRUE
              AND (:categorySlug = '' OR p.category.slug = :categorySlug)
              AND (:pattern = '%' OR LOWER(p.name) LIKE :pattern
                                  OR LOWER(COALESCE(p.nameMy, '')) LIKE :pattern)
            ORDER BY p.sortOrder ASC, p.id ASC
            """)
    List<Product> findPublic(@Param("categorySlug") String categorySlug,
                             @Param("pattern") String pattern);

    /** @param pattern build with {@link com.diashop.api.common.SearchPattern#of} */
    @Query("""
            SELECT p FROM Product p
            WHERE (:categoryId IS NULL OR p.category.id = :categoryId)
              AND (:active IS NULL OR p.active = :active)
              AND (:pattern = '%' OR LOWER(p.name) LIKE :pattern
                                  OR LOWER(p.slug) LIKE :pattern)
            """)
    Page<Product> searchForAdmin(@Param("pattern") String pattern,
                                 @Param("categoryId") Long categoryId,
                                 @Param("active") Boolean active,
                                 Pageable pageable);
}
