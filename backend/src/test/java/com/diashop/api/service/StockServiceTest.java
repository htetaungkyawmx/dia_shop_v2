package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.domain.Product;
import com.diashop.api.domain.ProductVariant;
import com.diashop.api.domain.StockCode;
import com.diashop.api.domain.StockCodeStatus;
import com.diashop.api.domain.StockMoveReason;
import com.diashop.api.domain.StockMovement;
import com.diashop.api.domain.StockType;
import com.diashop.api.domain.User;
import com.diashop.api.dto.AdminDtos.AddStockCodesRequest;
import com.diashop.api.dto.AdminDtos.StockAdjustRequest;
import com.diashop.api.dto.AdminDtos.StockSetRequest;
import com.diashop.api.repository.ProductVariantRepository;
import com.diashop.api.repository.StockCodeRepository;
import com.diashop.api.repository.StockMovementRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StockServiceTest {

    @Mock
    private ProductVariantRepository variantRepository;

    @Mock
    private StockCodeRepository codeRepository;

    @Mock
    private StockMovementRepository movementRepository;

    private StockService stockService;
    private User admin;

    @BeforeEach
    void setUp() {
        stockService = new StockService(variantRepository, codeRepository, movementRepository);
        admin = new User();
        admin.setId(1L);
        admin.setDisplayName("Admin");
    }

    private ProductVariant variant(StockType type, int quantity) {
        Product product = new Product();
        product.setName("Netflix Premium");

        ProductVariant variant = new ProductVariant();
        variant.setId(5L);
        variant.setProduct(product);
        variant.setName("1 Month");
        variant.setStockType(type);
        variant.setStockQuantity(quantity);
        return variant;
    }

    private StockMovement captureMovement() {
        var captor = ArgumentCaptor.forClass(StockMovement.class);
        verify(movementRepository).save(captor.capture());
        return captor.getValue();
    }

    @Test
    @DisplayName("an unlimited package never decrements and writes no movement")
    void unlimitedStockIsANoOp() {
        when(variantRepository.findByIdForUpdate(5L))
                .thenReturn(Optional.of(variant(StockType.UNLIMITED, 0)));

        stockService.reserveForSale(5L, 3, 99L);

        verify(movementRepository, never()).save(any());
    }

    @Test
    @DisplayName("a limited package decrements and records the sale")
    void limitedStockDecrementsOnSale() {
        ProductVariant variant = variant(StockType.LIMITED, 10);
        when(variantRepository.findByIdForUpdate(5L)).thenReturn(Optional.of(variant));

        stockService.reserveForSale(5L, 3, 99L);

        assertThat(variant.getStockQuantity()).isEqualTo(7);
        StockMovement movement = captureMovement();
        assertThat(movement.getDelta()).isEqualTo(-3);
        assertThat(movement.getQuantityBefore()).isEqualTo(10);
        assertThat(movement.getQuantityAfter()).isEqualTo(7);
        assertThat(movement.getReason()).isEqualTo(StockMoveReason.SALE);
    }

    @Test
    @DisplayName("buying more than is on hand is refused before any stock moves")
    void oversellingIsRefused() {
        ProductVariant variant = variant(StockType.LIMITED, 2);
        when(variantRepository.findByIdForUpdate(5L)).thenReturn(Optional.of(variant));

        assertThatThrownBy(() -> stockService.reserveForSale(5L, 3, 99L))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> assertThat(((ApiException) e).getCode()).isEqualTo("OUT_OF_STOCK"))
                .hasMessageContaining("only has 2 left");

        assertThat(variant.getStockQuantity()).isEqualTo(2);
        verify(movementRepository, never()).save(any());
    }

    @Test
    @DisplayName("a rejected order returns limited stock to the shelf")
    void releaseReturnsStock() {
        ProductVariant variant = variant(StockType.LIMITED, 7);
        when(variantRepository.findByIdForUpdate(5L)).thenReturn(Optional.of(variant));

        stockService.releaseFromSale(5L, 3, 99L);

        assertThat(variant.getStockQuantity()).isEqualTo(10);
        assertThat(captureMovement().getReason()).isEqualTo(StockMoveReason.REFUND);
    }

    @Test
    @DisplayName("an adjustment that would go below zero is refused")
    void adjustCannotGoNegative() {
        when(variantRepository.findByIdForUpdate(5L))
                .thenReturn(Optional.of(variant(StockType.LIMITED, 4)));

        assertThatThrownBy(() -> stockService.adjust(
                5L, new StockAdjustRequest(-5, StockMoveReason.DAMAGE, "lost"), admin))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> assertThat(((ApiException) e).getCode()).isEqualTo("NEGATIVE_STOCK"));

        verify(movementRepository, never()).save(any());
    }

    @Test
    @DisplayName("a zero adjustment is refused rather than writing an empty movement")
    void adjustRejectsZeroDelta() {
        when(variantRepository.findByIdForUpdate(5L))
                .thenReturn(Optional.of(variant(StockType.LIMITED, 4)));

        assertThatThrownBy(() -> stockService.adjust(
                5L, new StockAdjustRequest(0, StockMoveReason.MANUAL_ADJUST, "nothing"), admin))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> assertThat(((ApiException) e).getCode()).isEqualTo("INVALID_DELTA"));
    }

    @Test
    @DisplayName("adjusting an unlimited package is refused with an actionable message")
    void adjustRefusesUnlimited() {
        when(variantRepository.findByIdForUpdate(5L))
                .thenReturn(Optional.of(variant(StockType.UNLIMITED, 0)));

        assertThatThrownBy(() -> stockService.adjust(
                5L, new StockAdjustRequest(5, StockMoveReason.RESTOCK, "restock"), admin))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Switch it to Limited first");
    }

    @Test
    @DisplayName("a recount writes the difference as a correction")
    void setQuantityRecordsTheDifference() {
        ProductVariant variant = variant(StockType.LIMITED, 35);
        when(variantRepository.findByIdForUpdate(5L)).thenReturn(Optional.of(variant));

        stockService.setQuantity(5L, new StockSetRequest(12, "Physical recount"), admin);

        assertThat(variant.getStockQuantity()).isEqualTo(12);
        StockMovement movement = captureMovement();
        assertThat(movement.getDelta()).isEqualTo(-23);
        assertThat(movement.getReason()).isEqualTo(StockMoveReason.CORRECTION);
    }

    @Test
    @DisplayName("a recount to the same number writes nothing")
    void setQuantityIsANoOpWhenUnchanged() {
        when(variantRepository.findByIdForUpdate(5L))
                .thenReturn(Optional.of(variant(StockType.LIMITED, 12)));

        stockService.setQuantity(5L, new StockSetRequest(12, "recount"), admin);

        verify(movementRepository, never()).save(any());
    }

    @Test
    @DisplayName("uploaded codes are de-duplicated within the batch and against storage")
    void addCodesDeduplicates() {
        ProductVariant variant = variant(StockType.CODE_POOL, 0);
        when(variantRepository.findById(5L)).thenReturn(Optional.of(variant));
        when(codeRepository.existsByVariantIdAndCode(eq(5L), anyString())).thenReturn(false);
        when(codeRepository.countByVariantIdAndStatus(5L, StockCodeStatus.AVAILABLE)).thenReturn(2L);

        var result = stockService.addCodes(
                5L, new AddStockCodesRequest(List.of("AAA-111", "BBB-222", "AAA-111"), null), admin);

        assertThat(result.added()).isEqualTo(2);
        assertThat(result.skippedDuplicates()).isEqualTo(1);
        assertThat(result.availableNow()).isEqualTo(2);
        // The mirrored counter follows the real pool size.
        assertThat(variant.getStockQuantity()).isEqualTo(2);
    }

    @Test
    @DisplayName("codes cannot be uploaded to a package that is not a code pool")
    void addCodesRefusesNonCodePool() {
        when(variantRepository.findById(5L))
                .thenReturn(Optional.of(variant(StockType.LIMITED, 4)));

        assertThatThrownBy(() -> stockService.addCodes(
                5L, new AddStockCodesRequest(List.of("AAA-111"), null), admin))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> assertThat(((ApiException) e).getCode()).isEqualTo("NOT_CODE_POOL"));
    }

    @Test
    @DisplayName("claiming codes marks them sold and ties them to the order item")
    void assignCodesMarksThemSold() {
        StockCode first = new StockCode();
        first.setCode("AAA-111");
        StockCode second = new StockCode();
        second.setCode("BBB-222");
        when(codeRepository.claimAvailable(eq(5L), any(Pageable.class)))
                .thenReturn(List.of(first, second));

        var claimed = stockService.assignCodes(5L, 2, 77L);

        assertThat(claimed).hasSize(2);
        assertThat(claimed).allSatisfy(code -> {
            assertThat(code.getStatus()).isEqualTo(StockCodeStatus.SOLD);
            assertThat(code.getOrderItemId()).isEqualTo(77L);
            assertThat(code.getAssignedAt()).isNotNull();
        });
    }

    @Test
    @DisplayName("an order asking for more codes than exist fails instead of under-delivering")
    void assignCodesFailsWhenPoolIsShort() {
        StockCode only = new StockCode();
        only.setCode("AAA-111");
        when(codeRepository.claimAvailable(eq(5L), any(Pageable.class))).thenReturn(List.of(only));
        when(variantRepository.findById(5L))
                .thenReturn(Optional.of(variant(StockType.CODE_POOL, 1)));

        assertThatThrownBy(() -> stockService.assignCodes(5L, 3, 77L))
                .isInstanceOf(ApiException.class)
                .satisfies(e -> assertThat(((ApiException) e).getCode()).isEqualTo("OUT_OF_STOCK"))
                .hasMessageContaining("only has 1 code(s) left");
    }

    @Test
    @DisplayName("codes from a cancelled order are voided, never returned to the pool")
    void voidedCodesAreNotResold() {
        StockCode issued = new StockCode();
        issued.setStatus(StockCodeStatus.SOLD);
        when(codeRepository.findByOrderItemIdAndStatus(77L, StockCodeStatus.SOLD))
                .thenReturn(List.of(issued));

        assertThatCode(() -> stockService.voidCodesForOrderItem(77L)).doesNotThrowAnyException();

        assertThat(issued.getStatus()).isEqualTo(StockCodeStatus.VOID);
        verify(codeRepository).saveAll(any());
    }

    @Test
    @DisplayName("availability reflects the stock model of each package")
    void availabilityDependsOnStockType() {
        when(codeRepository.countByVariantIdAndStatus(anyLong(), eq(StockCodeStatus.AVAILABLE)))
                .thenReturn(4L);

        assertThat(stockService.availableOf(variant(StockType.UNLIMITED, 0))).isEqualTo(Integer.MAX_VALUE);
        assertThat(stockService.availableOf(variant(StockType.LIMITED, 9))).isEqualTo(9);
        assertThat(stockService.availableOf(variant(StockType.CODE_POOL, 0))).isEqualTo(4);
    }
}
