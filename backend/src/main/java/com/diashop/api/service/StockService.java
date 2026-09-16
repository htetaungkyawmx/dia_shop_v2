package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.domain.ProductVariant;
import com.diashop.api.domain.StockCode;
import com.diashop.api.domain.StockCodeStatus;
import com.diashop.api.domain.StockMoveReason;
import com.diashop.api.domain.StockMovement;
import com.diashop.api.domain.StockType;
import com.diashop.api.domain.User;
import com.diashop.api.dto.AdminDtos.AddStockCodesRequest;
import com.diashop.api.dto.AdminDtos.AddStockCodesResponse;
import com.diashop.api.dto.AdminDtos.StockAdjustRequest;
import com.diashop.api.dto.AdminDtos.StockMovementResponse;
import com.diashop.api.dto.AdminDtos.StockSetRequest;
import com.diashop.api.repository.ProductVariantRepository;
import com.diashop.api.repository.StockCodeRepository;
import com.diashop.api.repository.StockMovementRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

/**
 * Owns every stock read and write.
 *
 * Three stock models are supported per variant:
 *   UNLIMITED  - digital top-ups fulfilled by hand; never runs out
 *   LIMITED    - a counter (stock_quantity), e.g. Netflix slots
 *   CODE_POOL  - a queue of unique keys in stock_codes, e.g. gift cards
 */
@Service
@RequiredArgsConstructor
public class StockService {

    private final ProductVariantRepository variantRepository;
    private final StockCodeRepository codeRepository;
    private final StockMovementRepository movementRepository;

    // ------------------------------------------------------------- queries

    @Transactional(readOnly = true)
    public int availableOf(ProductVariant variant) {
        return switch (variant.getStockType()) {
            case UNLIMITED -> Integer.MAX_VALUE;
            case LIMITED -> variant.getStockQuantity();
            case CODE_POOL -> (int) codeRepository.countByVariantIdAndStatus(variant.getId(), StockCodeStatus.AVAILABLE);
        };
    }

    /** Batch version so a product page does not run one count query per variant. */
    @Transactional(readOnly = true)
    public Map<Long, Integer> availabilityFor(List<ProductVariant> variants) {
        Map<Long, Integer> result = new HashMap<>();
        List<Long> codePoolIds = variants.stream()
                .filter(v -> v.getStockType() == StockType.CODE_POOL)
                .map(ProductVariant::getId)
                .toList();

        Map<Long, Integer> codeCounts = new HashMap<>();
        if (!codePoolIds.isEmpty()) {
            for (Object[] row : codeRepository.countAvailableByVariantIds(codePoolIds)) {
                codeCounts.put(((Number) row[0]).longValue(), ((Number) row[1]).intValue());
            }
        }

        for (ProductVariant variant : variants) {
            int available = switch (variant.getStockType()) {
                case UNLIMITED -> Integer.MAX_VALUE;
                case LIMITED -> variant.getStockQuantity();
                case CODE_POOL -> codeCounts.getOrDefault(variant.getId(), 0);
            };
            result.put(variant.getId(), available);
        }
        return result;
    }

    // ------------------------------------------------------- order support

    /**
     * Reserves {@code quantity} units at checkout. The variant row is locked
     * first, so the last unit can only be taken once.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public void reserveForSale(Long variantId, int quantity, Long orderId) {
        ProductVariant variant = variantRepository.findByIdForUpdate(variantId)
                .orElseThrow(() -> ApiException.notFound("Package"));

        if (variant.getStockType() == StockType.UNLIMITED) {
            return;
        }
        if (variant.getStockType() == StockType.LIMITED) {
            if (variant.getStockQuantity() < quantity) {
                throw ApiException.conflict("OUT_OF_STOCK",
                        "\"" + variant.getName() + "\" only has " + variant.getStockQuantity() + " left.");
            }
            applyDelta(variant, -quantity, StockMoveReason.SALE, "Order #" + orderId, orderId, null);
        }
        // CODE_POOL stock is taken in assignCodes once the order item exists.
    }

    /**
     * Hands out the actual keys for a CODE_POOL item. Returns the claimed codes
     * in order; the caller copies them onto the order item.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public List<StockCode> assignCodes(Long variantId, int quantity, Long orderItemId) {
        List<StockCode> claimed = codeRepository.claimAvailable(variantId, PageRequest.of(0, quantity));
        if (claimed.size() < quantity) {
            ProductVariant variant = variantRepository.findById(variantId)
                    .orElseThrow(() -> ApiException.notFound("Package"));
            throw ApiException.conflict("OUT_OF_STOCK",
                    "\"" + variant.getName() + "\" only has " + claimed.size() + " code(s) left.");
        }
        Instant now = Instant.now();
        for (StockCode code : claimed) {
            code.setStatus(StockCodeStatus.SOLD);
            code.setOrderItemId(orderItemId);
            code.setAssignedAt(now);
        }
        codeRepository.saveAll(claimed);
        return claimed;
    }

    /** Puts stock back when an order is rejected, cancelled or refunded. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void releaseFromSale(Long variantId, int quantity, Long orderId) {
        ProductVariant variant = variantRepository.findByIdForUpdate(variantId)
                .orElseThrow(() -> ApiException.notFound("Package"));
        if (variant.getStockType() == StockType.LIMITED) {
            applyDelta(variant, quantity, StockMoveReason.REFUND, "Returned from order #" + orderId, orderId, null);
        }
    }

    /**
     * Voids codes that were handed to a cancelled order. They are not returned
     * to the pool: the buyer may already have seen them.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public void voidCodesForOrderItem(Long orderItemId) {
        List<StockCode> issued = codeRepository.findByOrderItemIdAndStatus(orderItemId, StockCodeStatus.SOLD);
        issued.forEach(c -> c.setStatus(StockCodeStatus.VOID));
        codeRepository.saveAll(issued);
    }

    // -------------------------------------------------------- admin writes

    @Transactional
    public ProductVariant adjust(Long variantId, StockAdjustRequest request, User actor) {
        ProductVariant variant = variantRepository.findByIdForUpdate(variantId)
                .orElseThrow(() -> ApiException.notFound("Package"));
        requireCounterStock(variant);

        if (request.delta() == 0) {
            throw ApiException.badRequest("INVALID_DELTA", "Adjustment must not be zero.");
        }
        if (variant.getStockQuantity() + request.delta() < 0) {
            throw ApiException.badRequest("NEGATIVE_STOCK",
                    "That would take stock below zero. Current stock is " + variant.getStockQuantity() + ".");
        }
        applyDelta(variant, request.delta(), request.reason(), request.note(), null, actor);
        return variant;
    }

    /** Sets an absolute count, e.g. after a physical recount. */
    @Transactional
    public ProductVariant setQuantity(Long variantId, StockSetRequest request, User actor) {
        ProductVariant variant = variantRepository.findByIdForUpdate(variantId)
                .orElseThrow(() -> ApiException.notFound("Package"));
        requireCounterStock(variant);

        int delta = request.quantity() - variant.getStockQuantity();
        if (delta == 0) {
            return variant;
        }
        applyDelta(variant, delta, StockMoveReason.CORRECTION, request.note(), null, actor);
        return variant;
    }

    @Transactional
    public AddStockCodesResponse addCodes(Long variantId, AddStockCodesRequest request, User actor) {
        ProductVariant variant = variantRepository.findById(variantId)
                .orElseThrow(() -> ApiException.notFound("Package"));
        if (variant.getStockType() != StockType.CODE_POOL) {
            throw ApiException.badRequest("NOT_CODE_POOL",
                    "\"" + variant.getName() + "\" does not use code stock. Adjust its quantity instead.");
        }

        // De-duplicate within the batch as well as against what is already stored.
        LinkedHashSet<String> unique = new LinkedHashSet<>();
        request.codes().stream()
                .map(String::trim)
                .filter(c -> !c.isEmpty())
                .forEach(unique::add);

        int added = 0;
        int skipped = request.codes().size() - unique.size();
        for (String raw : unique) {
            if (codeRepository.existsByVariantIdAndCode(variantId, raw)) {
                skipped++;
                continue;
            }
            StockCode code = new StockCode();
            code.setVariant(variant);
            code.setCode(raw);
            code.setSecret(request.secret());
            code.setStatus(StockCodeStatus.AVAILABLE);
            code.setCreatedBy(actor);
            codeRepository.save(code);
            added++;
        }

        int available = (int) codeRepository.countByVariantIdAndStatus(variantId, StockCodeStatus.AVAILABLE);

        // Mirror the pool size onto the variant so one column drives every
        // "in stock" badge regardless of stock type.
        StockMovement movement = new StockMovement();
        movement.setVariant(variant);
        movement.setDelta(added);
        movement.setQuantityBefore(variant.getStockQuantity());
        movement.setQuantityAfter(available);
        movement.setReason(StockMoveReason.RESTOCK);
        movement.setNote("Added " + added + " code(s)");
        movement.setCreatedBy(actor);
        movementRepository.save(movement);

        variant.setStockQuantity(available);
        variantRepository.save(variant);

        return new AddStockCodesResponse(added, skipped, available);
    }

    @Transactional(readOnly = true)
    public Page<StockMovementResponse> movements(Long variantId, Pageable pageable) {
        return movementRepository.findByVariantIdOrderByCreatedAtDescIdDesc(variantId, pageable)
                .map(m -> new StockMovementResponse(
                        m.getId(),
                        m.getVariant().getId(),
                        m.getDelta(),
                        m.getQuantityBefore(),
                        m.getQuantityAfter(),
                        m.getReason(),
                        m.getNote(),
                        m.getCreatedBy() == null ? "system" : m.getCreatedBy().getDisplayName(),
                        m.getCreatedAt()));
    }

    /** Re-syncs the mirrored counter for a code pool after codes are consumed. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void syncCodePoolCount(ProductVariant variant) {
        if (variant.getStockType() != StockType.CODE_POOL) {
            return;
        }
        int available = (int) codeRepository.countByVariantIdAndStatus(variant.getId(), StockCodeStatus.AVAILABLE);
        variant.setStockQuantity(available);
        variantRepository.save(variant);
    }

    private void applyDelta(ProductVariant variant, int delta, StockMoveReason reason,
                            String note, Long referenceId, User actor) {
        int before = variant.getStockQuantity();
        int after = before + delta;

        variant.setStockQuantity(after);
        variantRepository.save(variant);

        StockMovement movement = new StockMovement();
        movement.setVariant(variant);
        movement.setDelta(delta);
        movement.setQuantityBefore(before);
        movement.setQuantityAfter(after);
        movement.setReason(reason);
        movement.setNote(note);
        movement.setReferenceId(referenceId);
        movement.setCreatedBy(actor);
        movementRepository.save(movement);
    }

    private void requireCounterStock(ProductVariant variant) {
        if (variant.getStockType() == StockType.UNLIMITED) {
            throw ApiException.badRequest("UNLIMITED_STOCK",
                    "\"" + variant.getName() + "\" has unlimited stock. Switch it to Limited first.");
        }
        if (variant.getStockType() == StockType.CODE_POOL) {
            throw ApiException.badRequest("CODE_POOL_STOCK",
                    "\"" + variant.getName() + "\" is stocked with codes. Add or remove codes instead.");
        }
    }
}
