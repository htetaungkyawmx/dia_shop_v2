package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.dto.AdminDtos.AddStockCodesRequest;
import com.diashop.api.dto.AdminDtos.AddStockCodesResponse;
import com.diashop.api.dto.AdminDtos.StockAdjustRequest;
import com.diashop.api.dto.AdminDtos.StockCodeResponse;
import com.diashop.api.dto.AdminDtos.StockMovementResponse;
import com.diashop.api.dto.AdminDtos.StockSetRequest;
import com.diashop.api.dto.CatalogDtos.AdminVariantResponse;
import com.diashop.api.repository.StockCodeRepository;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.AdminCatalogService;
import com.diashop.api.service.StockService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.function.Function;

@Tag(name = "Admin · Stock")
@RestController
@RequestMapping(ApiPaths.ADMIN + "/variants/{variantId}/stock")
@RequiredArgsConstructor
public class AdminStockController {

    private final StockService stockService;
    private final AdminCatalogService adminCatalogService;
    private final StockCodeRepository stockCodeRepository;
    private final CurrentUserService currentUserService;

    @Operation(summary = "Add to or remove from stock, e.g. +20 restock or -2 damaged")
    @PostMapping("/adjust")
    public AdminVariantResponse adjust(@CurrentUser AuthUser principal,
                                       @PathVariable Long variantId,
                                       @Valid @RequestBody StockAdjustRequest request) {
        stockService.adjust(variantId, request, currentUserService.require(principal));
        return adminCatalogService.variantResponse(variantId);
    }

    @Operation(summary = "Set the exact stock count, e.g. after a recount")
    @PutMapping
    public AdminVariantResponse setQuantity(@CurrentUser AuthUser principal,
                                            @PathVariable Long variantId,
                                            @Valid @RequestBody StockSetRequest request) {
        stockService.setQuantity(variantId, request, currentUserService.require(principal));
        return adminCatalogService.variantResponse(variantId);
    }

    @Operation(summary = "Full stock history for this package")
    @GetMapping("/movements")
    public PageResponse<StockMovementResponse> movements(@PathVariable Long variantId,
                                                         @RequestParam(defaultValue = "0") int page,
                                                         @RequestParam(defaultValue = "30") int size) {
        return PageResponse.from(
                stockService.movements(variantId, PageRequests.of(page, size)),
                Function.identity());
    }

    @Operation(summary = "Upload gift card or licence keys into a code pool")
    @PostMapping("/codes")
    public AddStockCodesResponse addCodes(@CurrentUser AuthUser principal,
                                          @PathVariable Long variantId,
                                          @Valid @RequestBody AddStockCodesRequest request) {
        return stockService.addCodes(variantId, request, currentUserService.require(principal));
    }

    @Operation(summary = "List codes in the pool. Values are masked; only the buyer sees the full code.")
    @GetMapping("/codes")
    public PageResponse<StockCodeResponse> codes(@PathVariable Long variantId,
                                                 @RequestParam(defaultValue = "0") int page,
                                                 @RequestParam(defaultValue = "30") int size) {
        return PageResponse.from(
                stockCodeRepository.findByVariantIdOrderByIdDesc(variantId, PageRequests.of(page, size)),
                code -> new StockCodeResponse(
                        code.getId(),
                        mask(code.getCode()),
                        code.getStatus().name(),
                        code.getOrderItemId(),
                        code.getAssignedAt(),
                        code.getCreatedAt()));
    }

    private String mask(String code) {
        if (code == null || code.length() <= 4) {
            return "••••";
        }
        return "••••" + code.substring(code.length() - 4);
    }
}
