package com.diashop.api.repository;

import com.diashop.api.domain.Banner;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface BannerRepository extends JpaRepository<Banner, Long> {

    @Query("""
            SELECT b FROM Banner b
            WHERE b.active = TRUE
              AND (b.startsAt IS NULL OR b.startsAt <= :now)
              AND (b.endsAt IS NULL OR b.endsAt >= :now)
            ORDER BY b.sortOrder ASC, b.id ASC
            """)
    List<Banner> findVisible(@Param("now") Instant now);

    List<Banner> findAllByOrderBySortOrderAscIdAsc();
}
