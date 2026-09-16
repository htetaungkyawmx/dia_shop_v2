package com.diashop.api.service;

import com.diashop.api.domain.OrderStatus;
import com.diashop.api.domain.StockType;
import com.diashop.api.domain.TicketStatus;
import com.diashop.api.domain.TopupStatus;
import com.diashop.api.domain.UserStatus;
import com.diashop.api.dto.AdminDtos.DailyPoint;
import com.diashop.api.dto.AdminDtos.DashboardResponse;
import com.diashop.api.dto.AdminDtos.LowStockItem;
import com.diashop.api.dto.AdminDtos.TopSeller;
import com.diashop.api.repository.OrderRepository;
import com.diashop.api.repository.ProductVariantRepository;
import com.diashop.api.repository.SupportTicketRepository;
import com.diashop.api.repository.TopupRequestRepository;
import com.diashop.api.repository.UserRepository;
import com.diashop.api.repository.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final OrderRepository orderRepository;
    private final TopupRequestRepository topupRepository;
    private final SupportTicketRepository ticketRepository;
    private final UserRepository userRepository;
    private final WalletRepository walletRepository;
    private final ProductVariantRepository variantRepository;

    @Transactional(readOnly = true)
    public DashboardResponse load() {
        ZoneId zone = ZoneId.systemDefault();
        Instant startOfToday = LocalDate.now(zone).atStartOfDay(zone).toInstant();
        Instant sevenDaysAgo = startOfToday.minusSeconds(6 * 86_400L);
        Instant thirtyDaysAgo = startOfToday.minusSeconds(29 * 86_400L);

        List<DailyPoint> series = orderRepository.dailyRevenue(LocalDate.now(zone).minusDays(29)).stream()
                .map(row -> new DailyPoint(
                        String.valueOf(row[0]),
                        ((Number) row[1]).longValue(),
                        ((Number) row[2]).longValue()))
                .toList();

        List<TopSeller> topSellers = orderRepository.topSellers(thirtyDaysAgo, PageRequest.of(0, 8)).stream()
                .map(row -> new TopSeller(
                        (String) row[0],
                        (String) row[1],
                        ((Number) row[2]).longValue(),
                        ((Number) row[3]).longValue()))
                .toList();

        List<LowStockItem> lowStock = variantRepository.findLowStock(StockType.LIMITED).stream()
                .map(v -> new LowStockItem(v.getId(), v.getProduct().getName(), v.getName(),
                        v.getStockQuantity(), v.getLowStockThreshold(), v.getStockType()))
                .toList();
        List<LowStockItem> lowCodeStock = variantRepository.findLowStock(StockType.CODE_POOL).stream()
                .map(v -> new LowStockItem(v.getId(), v.getProduct().getName(), v.getName(),
                        v.getStockQuantity(), v.getLowStockThreshold(), v.getStockType()))
                .toList();

        return new DashboardResponse(
                orderRepository.countByStatus(OrderStatus.PENDING),
                topupRepository.countByStatus(TopupStatus.PENDING),
                ticketRepository.countByStatus(TicketStatus.OPEN),
                userRepository.count(),
                userRepository.countByStatus(UserStatus.ACTIVE),
                userRepository.countCreatedSince(sevenDaysAgo),
                orderRepository.revenueSince(startOfToday),
                orderRepository.revenueSince(sevenDaysAgo),
                orderRepository.revenueSince(thirtyDaysAgo),
                orderRepository.profitSince(thirtyDaysAgo),
                orderRepository.countSince(startOfToday),
                orderRepository.countSince(thirtyDaysAgo),
                topupRepository.approvedAmountSince(thirtyDaysAgo),
                walletRepository.totalBalance(),
                series,
                topSellers,
                java.util.stream.Stream.concat(lowStock.stream(), lowCodeStock.stream()).toList());
    }
}
