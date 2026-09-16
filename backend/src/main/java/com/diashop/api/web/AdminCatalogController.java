package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.dto.AdminDtos.BannerUpsertRequest;
import com.diashop.api.dto.AdminDtos.CategoryUpsertRequest;
import com.diashop.api.dto.AdminDtos.PaymentMethodUpsertRequest;
import com.diashop.api.dto.AdminDtos.ProductUpsertRequest;
import com.diashop.api.dto.AdminDtos.VariantUpsertRequest;
import com.diashop.api.dto.CatalogDtos.AdminProductResponse;
import com.diashop.api.dto.CatalogDtos.AdminVariantResponse;
import com.diashop.api.dto.CatalogDtos.BannerResponse;
import com.diashop.api.dto.CatalogDtos.CategoryResponse;
import com.diashop.api.dto.MiscDtos.SimpleMessage;
import com.diashop.api.dto.WalletDtos.PaymentMethodResponse;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.AdminCatalogService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.function.Function;

@Tag(name = "Admin · Catalog")
@RestController
@RequestMapping(ApiPaths.ADMIN)
@RequiredArgsConstructor
public class AdminCatalogController {

    private final AdminCatalogService catalogService;
    private final CurrentUserService currentUserService;

    // ----------------------------------------------------------- categories

    @GetMapping("/categories")
    public List<CategoryResponse> categories() {
        return catalogService.categories();
    }

    @PostMapping("/categories")
    public ResponseEntity<CategoryResponse> createCategory(@CurrentUser AuthUser principal,
                                                           @Valid @RequestBody CategoryUpsertRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(catalogService.createCategory(request, currentUserService.require(principal)));
    }

    @PutMapping("/categories/{id}")
    public CategoryResponse updateCategory(@CurrentUser AuthUser principal,
                                           @PathVariable Long id,
                                           @Valid @RequestBody CategoryUpsertRequest request) {
        return catalogService.updateCategory(id, request, currentUserService.require(principal));
    }

    @DeleteMapping("/categories/{id}")
    public SimpleMessage deleteCategory(@CurrentUser AuthUser principal, @PathVariable Long id) {
        catalogService.deleteCategory(id, currentUserService.require(principal));
        return SimpleMessage.of("Category deleted.");
    }

    // ------------------------------------------------------------- products

    @GetMapping("/products")
    public PageResponse<AdminProductResponse> products(@RequestParam(required = false) String q,
                                                       @RequestParam(required = false) Long categoryId,
                                                       @RequestParam(required = false) Boolean active,
                                                       @RequestParam(defaultValue = "0") int page,
                                                       @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                catalogService.products(q, categoryId, active, PageRequests.of(page, size)),
                Function.identity());
    }

    @GetMapping("/products/{id}")
    public AdminProductResponse product(@PathVariable Long id) {
        return catalogService.product(id);
    }

    @PostMapping("/products")
    public ResponseEntity<AdminProductResponse> createProduct(@CurrentUser AuthUser principal,
                                                              @Valid @RequestBody ProductUpsertRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(catalogService.createProduct(request, currentUserService.require(principal)));
    }

    @PutMapping("/products/{id}")
    public AdminProductResponse updateProduct(@CurrentUser AuthUser principal,
                                              @PathVariable Long id,
                                              @Valid @RequestBody ProductUpsertRequest request) {
        return catalogService.updateProduct(id, request, currentUserService.require(principal));
    }

    @Operation(summary = "Hide a product from the shop. Past orders keep referring to it.")
    @DeleteMapping("/products/{id}")
    public SimpleMessage archiveProduct(@CurrentUser AuthUser principal, @PathVariable Long id) {
        catalogService.archiveProduct(id, currentUserService.require(principal));
        return SimpleMessage.of("Product archived.");
    }

    // ------------------------------------------------------------- variants

    @PostMapping("/products/{productId}/variants")
    public ResponseEntity<AdminVariantResponse> createVariant(@CurrentUser AuthUser principal,
                                                              @PathVariable Long productId,
                                                              @Valid @RequestBody VariantUpsertRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(catalogService.createVariant(productId, request, currentUserService.require(principal)));
    }

    @Operation(summary = "Update a package. Stock is changed through the stock endpoints instead.")
    @PutMapping("/variants/{id}")
    public AdminVariantResponse updateVariant(@CurrentUser AuthUser principal,
                                              @PathVariable Long id,
                                              @Valid @RequestBody VariantUpsertRequest request) {
        return catalogService.updateVariant(id, request, currentUserService.require(principal));
    }

    @DeleteMapping("/variants/{id}")
    public SimpleMessage archiveVariant(@CurrentUser AuthUser principal, @PathVariable Long id) {
        catalogService.archiveVariant(id, currentUserService.require(principal));
        return SimpleMessage.of("Package archived.");
    }

    // -------------------------------------------------------------- banners

    @GetMapping("/banners")
    public List<BannerResponse> banners() {
        return catalogService.banners();
    }

    @PostMapping("/banners")
    public ResponseEntity<BannerResponse> createBanner(@CurrentUser AuthUser principal,
                                                       @Valid @RequestBody BannerUpsertRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(catalogService.createBanner(request, currentUserService.require(principal)));
    }

    @PutMapping("/banners/{id}")
    public BannerResponse updateBanner(@CurrentUser AuthUser principal,
                                       @PathVariable Long id,
                                       @Valid @RequestBody BannerUpsertRequest request) {
        return catalogService.updateBanner(id, request, currentUserService.require(principal));
    }

    @DeleteMapping("/banners/{id}")
    public SimpleMessage deleteBanner(@CurrentUser AuthUser principal, @PathVariable Long id) {
        catalogService.deleteBanner(id, currentUserService.require(principal));
        return SimpleMessage.of("Banner deleted.");
    }

    // ------------------------------------------------------ payment methods

    @GetMapping("/payment-methods")
    public List<PaymentMethodResponse> paymentMethods() {
        return catalogService.paymentMethods();
    }

    @PostMapping("/payment-methods")
    public ResponseEntity<PaymentMethodResponse> createPaymentMethod(
            @CurrentUser AuthUser principal,
            @Valid @RequestBody PaymentMethodUpsertRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(catalogService.createPaymentMethod(request, currentUserService.require(principal)));
    }

    @PutMapping("/payment-methods/{id}")
    public PaymentMethodResponse updatePaymentMethod(@CurrentUser AuthUser principal,
                                                     @PathVariable Long id,
                                                     @Valid @RequestBody PaymentMethodUpsertRequest request) {
        return catalogService.updatePaymentMethod(id, request, currentUserService.require(principal));
    }
}
