package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.domain.NotificationType;
import com.diashop.api.domain.SupportTicket;
import com.diashop.api.domain.TicketStatus;
import com.diashop.api.domain.User;
import com.diashop.api.dto.AdminDtos.TicketReplyRequest;
import com.diashop.api.dto.MiscDtos.CreateTicketRequest;
import com.diashop.api.dto.MiscDtos.TicketResponse;
import com.diashop.api.repository.OrderRepository;
import com.diashop.api.repository.SupportTicketRepository;
import com.diashop.api.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class SupportService {

    private final SupportTicketRepository ticketRepository;
    private final UserRepository userRepository;
    private final OrderRepository orderRepository;
    private final NotificationService notificationService;

    @Transactional
    public TicketResponse create(Long userId, CreateTicketRequest request) {
        User user = userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User"));

        SupportTicket ticket = new SupportTicket();
        ticket.setUser(user);
        ticket.setSubject(request.subject().trim());
        ticket.setMessage(request.message().trim());
        if (request.orderId() != null) {
            orderRepository.findById(request.orderId())
                    .filter(o -> o.getUser().getId().equals(userId))
                    .ifPresent(ticket::setOrder);
        }
        return toResponse(ticketRepository.save(ticket));
    }

    @Transactional(readOnly = true)
    public Page<TicketResponse> listForUser(Long userId, Pageable pageable) {
        return ticketRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable).map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<TicketResponse> listForAdmin(TicketStatus status, Pageable pageable) {
        return (status == null
                ? ticketRepository.findAllByOrderByCreatedAtDesc(pageable)
                : ticketRepository.findByStatusOrderByCreatedAtDesc(status, pageable))
                .map(this::toResponse);
    }

    @Transactional
    public TicketResponse reply(Long ticketId, TicketReplyRequest request, User admin) {
        SupportTicket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> ApiException.notFound("Ticket"));
        ticket.setAdminReply(request.reply());
        ticket.setStatus(request.status());
        ticket.setRepliedBy(admin);
        ticket.setRepliedAt(Instant.now());
        ticketRepository.save(ticket);

        notificationService.notify(ticket.getUser(), NotificationType.GENERAL,
                "Support replied",
                "We answered your message \"" + ticket.getSubject() + "\".",
                Map.of("screen", "support", "ticketId", String.valueOf(ticket.getId())));
        return toResponse(ticket);
    }

    private TicketResponse toResponse(SupportTicket t) {
        return new TicketResponse(
                t.getId(),
                t.getSubject(),
                t.getMessage(),
                t.getStatus(),
                t.getAdminReply(),
                t.getRepliedAt(),
                t.getCreatedAt(),
                t.getOrder() == null ? null : t.getOrder().getOrderNo(),
                t.getUser().getEmail(),
                t.getUser().getDisplayName());
    }
}
