package com.diashop.api.repository;

import com.diashop.api.domain.Role;
import com.diashop.api.domain.User;
import com.diashop.api.domain.UserStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmailIgnoreCase(String email);

    Optional<User> findByGoogleId(String googleId);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByRoleIn(List<Role> roles);

    long countByStatus(UserStatus status);

    /** @param pattern build with {@link com.diashop.api.common.SearchPattern#of} */
    @Query("""
            SELECT u FROM User u
            WHERE (:status IS NULL OR u.status = :status)
              AND (:role IS NULL OR u.role = :role)
              AND (:pattern = '%' OR LOWER(u.email) LIKE :pattern
                                  OR LOWER(u.displayName) LIKE :pattern
                                  OR LOWER(COALESCE(u.phone, '')) LIKE :pattern)
            """)
    Page<User> search(@Param("pattern") String pattern,
                      @Param("status") UserStatus status,
                      @Param("role") Role role,
                      Pageable pageable);

    @Query("SELECT COUNT(u) FROM User u WHERE u.createdAt >= :since")
    long countCreatedSince(@Param("since") java.time.Instant since);
}
