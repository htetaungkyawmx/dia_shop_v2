package com.diashop.api.repository;

import com.diashop.api.domain.SupportTicket;
import com.diashop.api.domain.TicketStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupportTicketRepository extends JpaRepository<SupportTicket, Long> {

    Page<SupportTicket> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);

    @EntityGraph(attributePaths = {"user"})
    Page<SupportTicket> findByStatusOrderByCreatedAtDesc(TicketStatus status, Pageable pageable);

    @EntityGraph(attributePaths = {"user"})
    Page<SupportTicket> findAllByOrderByCreatedAtDesc(Pageable pageable);

    long countByStatus(TicketStatus status);
}
