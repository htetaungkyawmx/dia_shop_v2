package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.common.SearchPattern;
import com.diashop.api.domain.Banner;
import com.diashop.api.domain.Category;
import com.diashop.api.domain.PaymentMethod;
import com.diashop.api.domain.Product;
import com.diashop.api.domain.ProductField;
import com.diashop.api.domain.ProductVariant;
import com.diashop.api.domain.StockCodeStatus;
import com.diashop.api.domain.StockType;
import com.diashop.api.domain.User;
import com.diashop.api.dto.AdminDtos.BannerUpsertRequest;
import com.diashop.api.dto.AdminDtos.CategoryUpsertRequest;
import com.diashop.api.dto.AdminDtos.PaymentMethodUpsertRequest;
import com.diashop.api.dto.AdminDtos.ProductFieldRequest;
import com.diashop.api.dto.AdminDtos.ProductUpsertRequest;
import com.diashop.api.dto.AdminDtos.VariantUpsertRequest;
import com.diashop.api.dto.CatalogDtos.AdminProductResponse;
import com.diashop.api.dto.CatalogDtos.AdminVariantResponse;
import com.diashop.api.dto.CatalogDtos.BannerResponse;
import com.diashop.api.dto.CatalogDtos.CategoryResponse;
import com.diashop.api.dto.CatalogDtos.ProductFieldResponse;
import com.diashop.api.dto.WalletDtos.PaymentMethodResponse;
import com.diashop.api.repository.BannerRepository;
import com.diashop.api.repository.CategoryRepository;
import com.diashop.api.repository.PaymentMethodRepository;
import com.diashop.api.repository.ProductRepository;
import com.diashop.api.repository.ProductVariantRepository;
import com.diashop.api.repository.StockCodeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/** Catalog, banner and payment-method administration. */
@Service
@RequiredArgsConstructor
public class AdminCatalogService {

    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final ProductVariantRepository variantRepository;
    private final StockCodeRepository stockCodeRepository;
    private final BannerRepository bannerRepository;
    private final PaymentMethodRepository paymentMethodRepository;
    private final CatalogService catalogService;
    private final AuditService auditService;

    // ------------------------------------------------------------ category

    @Transactional(readOnly = true)
    public List<CategoryResponse> categories() {
        return categoryRepository.findAllByOrderBySortOrderAscIdAsc().stream()
                .map(CategoryResponse::of)
                .toList();
    }

    @Transactional
    public CategoryResponse createCategory(CategoryUpsertRequest request, User admin) {
        if (categoryRepository.existsBySlug(request.slug())) {
            throw ApiException.conflict("SLUG_TAKEN", "A category with that slug already exists.");
        }
        Category category = new Category();
        applyCategory(category, request);
        Category saved = categoryRepository.save(category);
        auditService.record(admin, "CATEGORY_CREATED", "Category", saved.getId(), saved.getSlug());
        return CategoryResponse.of(saved);
    }

    @Transactional
    public CategoryResponse updateCategory(Long id, CategoryUpsertRequest request, User admin) {
        Category category = categoryRepository.findById(id).orElseThrow(() -> ApiException.notFound("Category"));
        if (!category.getSlug().equals(request.slug()) && categoryRepository.existsBySlug(request.slug())) {
            throw ApiException.conflict("SLUG_TAKEN", "A category with that slug already exists.");
        }
        applyCategory(category, request);
        auditService.record(admin, "CATEGORY_UPDATED", "Category", id, request.slug());
        return CategoryResponse.of(categoryRepository.save(category));
    }

    @Transactional
    public void deleteCategory(Long id, User admin) {
        Category category = categoryRepository.findById(id).orElseThrow(() -> ApiException.notFound("Category"));
        Page<Product> products = productRepository.searchForAdmin(null, id, null, Pageable.ofSize(1));
        if (products.getTotalElements() > 0) {
            throw ApiException.conflict("CATEGORY_IN_USE",
                    "This category still has products. Move or delete them first.");
        }
        categoryRepository.delete(category);
        auditService.record(admin, "CATEGORY_DELETED", "Category", id, category.getSlug());
    }

    private void applyCategory(Category category, CategoryUpsertRequest r) {
        category.setSlug(r.slug());
        category.setName(r.name());
        category.setNameMy(r.nameMy());
        category.setIconUrl(r.iconUrl());
        category.setSortOrder(r.sortOrder());
        category.setActive(r.active());
    }

    // ------------------------------------------------------------- product

    @Transactional(readOnly = true)
    public Page<AdminProductResponse> products(String query, Long categoryId, Boolean active, Pageable pageable) {
        return productRepository.searchForAdmin(SearchPattern.of(query), categoryId, active, pageable)
                .map(this::toAdminProduct);
    }

    @Transactional(readOnly = true)
    public AdminProductResponse product(Long id) {
        return toAdminProduct(productRepository.findById(id).orElseThrow(() -> ApiException.notFound("Product")));
    }

    @Transactional
    public AdminProductResponse createProduct(ProductUpsertRequest request, User admin) {
        if (productRepository.existsBySlug(request.slug())) {
            throw ApiException.conflict("SLUG_TAKEN", "A product with that slug already exists.");
        }
        Product product = new Product();
        applyProduct(product, request);
        syncFields(product, request.fields());
        Product saved = productRepository.save(product);
        auditService.record(admin, "PRODUCT_CREATED", "Product", saved.getId(), saved.getSlug());
        return toAdminProduct(saved);
    }

    @Transactional
    public AdminProductResponse updateProduct(Long id, ProductUpsertRequest request, User admin) {
        Product product = productRepository.findById(id).orElseThrow(() -> ApiException.notFound("Product"));
        if (!product.getSlug().equals(request.slug()) && productRepository.existsBySlug(request.slug())) {
            throw ApiException.conflict("SLUG_TAKEN", "A product with that slug already exists.");
        }
        applyProduct(product, request);
        syncFields(product, request.fields());
        auditService.record(admin, "PRODUCT_UPDATED", "Product", id, request.slug());
        return toAdminProduct(productRepository.save(product));
    }

    /** Products are archived, never hard-deleted: past orders point at them. */
    @Transactional
    public void archiveProduct(Long id, User admin) {
        Product product = productRepository.findById(id).orElseThrow(() -> ApiException.notFound("Product"));
        product.setActive(false);
        product.setFeatured(false);
        product.getVariants().forEach(v -> v.setActive(false));
        productRepository.save(product);
        auditService.record(admin, "PRODUCT_ARCHIVED", "Product", id, product.getSlug());
    }

    private void applyProduct(Product product, ProductUpsertRequest r) {
        Category category = categoryRepository.findById(r.categoryId())
                .orElseThrow(() -> ApiException.notFound("Category"));
        product.setCategory(category);
        product.setSlug(r.slug());
        product.setName(r.name());
        product.setNameMy(r.nameMy());
        product.setDescription(r.description());
        product.setDescriptionMy(r.descriptionMy());
        product.setImageUrl(r.imageUrl());
        product.setBannerUrl(r.bannerUrl());
        product.setInstructions(r.instructions());
        product.setInstructionsMy(r.instructionsMy());
        product.setFulfillmentType(r.fulfillmentType());
        product.setSupplierGame(blankToNull(r.supplierGame()));
        product.setFeatured(r.featured());
        product.setSortOrder(r.sortOrder());
        product.setActive(r.active());
    }

    /** Replaces the field list, keeping rows whose id was sent back. */
    private void syncFields(Product product, List<ProductFieldRequest> requested) {
        if (requested == null) {
            return;
        }
        List<Long> keptIds = requested.stream()
                .map(ProductFieldRequest::id)
                .filter(Objects::nonNull)
                .toList();
        product.getFields().removeIf(f -> f.getId() != null && !keptIds.contains(f.getId()));

        for (ProductFieldRequest r : requested) {
            ProductField field = product.getFields().stream()
                    .filter(f -> f.getId() != null && f.getId().equals(r.id()))
                    .findFirst()
                    .orElseGet(() -> {
                        ProductField fresh = new ProductField();
                        product.addField(fresh);
                        return fresh;
                    });
            field.setFieldKey(r.key());
            field.setLabel(r.label());
            field.setLabelMy(r.labelMy());
            field.setPlaceholder(r.placeholder());
            field.setHelpText(r.helpText());
            field.setInputType(r.inputType());
            field.setOptions(catalogService.writeOptions(r.options()));
            field.setValidationRegex(r.validationRegex());
            field.setRequired(r.required());
            field.setSortOrder(r.sortOrder());
        }
    }

    // ------------------------------------------------------------- variant

    @Transactional
    public AdminVariantResponse createVariant(Long productId, VariantUpsertRequest request, User admin) {
        Product product = productRepository.findById(productId).orElseThrow(() -> ApiException.notFound("Product"));
        if (variantRepository.existsBySku(request.sku())) {
            throw ApiException.conflict("SKU_TAKEN", "A package with that SKU already exists.");
        }
        ProductVariant variant = new ProductVariant();
        variant.setProduct(product);
        applyVariant(variant, request, true);
        ProductVariant saved = variantRepository.save(variant);
        auditService.record(admin, "VARIANT_CREATED", "ProductVariant", saved.getId(), saved.getSku());
        return toAdminVariant(saved, 0);
    }

    @Transactional
    public AdminVariantResponse updateVariant(Long variantId, VariantUpsertRequest request, User admin) {
        ProductVariant variant = variantRepository.findWithProduct(variantId)
                .orElseThrow(() -> ApiException.notFound("Package"));
        if (!variant.getSku().equals(request.sku()) && variantRepository.existsBySku(request.sku())) {
            throw ApiException.conflict("SKU_TAKEN", "A package with that SKU already exists.");
        }
        // Stock is not editable here — it moves only through StockService so
        // every change leaves a stock_movements trail.
        applyVariant(variant, request, false);
        auditService.record(admin, "VARIANT_UPDATED", "ProductVariant", variantId, request.sku());
        ProductVariant saved = variantRepository.save(variant);
        int codes = saved.getStockType() == StockType.CODE_POOL
                ? (int) stockCodeRepository.countByVariantIdAndStatus(saved.getId(), StockCodeStatus.AVAILABLE)
                : 0;
        return toAdminVariant(saved, codes);
    }

    @Transactional
    public void archiveVariant(Long variantId, User admin) {
        ProductVariant variant = variantRepository.findById(variantId)
                .orElseThrow(() -> ApiException.notFound("Package"));
        variant.setActive(false);
        variantRepository.save(variant);
        auditService.record(admin, "VARIANT_ARCHIVED", "ProductVariant", variantId, variant.getSku());
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private void applyVariant(ProductVariant variant, VariantUpsertRequest r, boolean isNew) {
        variant.setSku(r.sku());
        variant.setName(r.name());
        variant.setNameMy(r.nameMy());
        variant.setBonusText(r.bonusText());
        variant.setDescription(r.description());
        variant.setPrice(r.price());
        variant.setCompareAtPrice(r.compareAtPrice());
        variant.setCostPrice(r.costPrice());
        variant.setImageUrl(r.imageUrl());
        variant.setLowStockThreshold(r.lowStockThreshold());
        variant.setMaxPerOrder(r.maxPerOrder());
        variant.setPopularity(r.popularity());
        variant.setSortOrder(r.sortOrder());
        variant.setActive(r.active());
        variant.setSupplier(blankToNull(r.supplier()));
        variant.setSupplierProductId(blankToNull(r.supplierProductId()));

        StockType previous = variant.getStockType();
        variant.setStockType(r.stockType());

        if (r.stockType() == StockType.UNLIMITED) {
            variant.setStockQuantity(0);
        } else if (isNew || previous != r.stockType()) {
            // Only seed the counter when the variant is new or its stock model
            // just changed; otherwise an edit would silently rewrite stock.
            variant.setStockQuantity(r.stockQuantity() == null ? 0 : r.stockQuantity());
        }
    }

    // ------------------------------------------------------------- banners

    @Transactional(readOnly = true)
    public List<BannerResponse> banners() {
        return bannerRepository.findAllByOrderBySortOrderAscIdAsc().stream().map(BannerResponse::of).toList();
    }

    @Transactional
    public BannerResponse createBanner(BannerUpsertRequest request, User admin) {
        Banner banner = new Banner();
        applyBanner(banner, request);
        Banner saved = bannerRepository.save(banner);
        auditService.record(admin, "BANNER_CREATED", "Banner", saved.getId(), saved.getTitle());
        return BannerResponse.of(saved);
    }

    @Transactional
    public BannerResponse updateBanner(Long id, BannerUpsertRequest request, User admin) {
        Banner banner = bannerRepository.findById(id).orElseThrow(() -> ApiException.notFound("Banner"));
        applyBanner(banner, request);
        auditService.record(admin, "BANNER_UPDATED", "Banner", id, request.title());
        return BannerResponse.of(bannerRepository.save(banner));
    }

    @Transactional
    public void deleteBanner(Long id, User admin) {
        bannerRepository.deleteById(id);
        auditService.record(admin, "BANNER_DELETED", "Banner", id, null);
    }

    private void applyBanner(Banner banner, BannerUpsertRequest r) {
        banner.setTitle(r.title());
        banner.setImageUrl(r.imageUrl());
        banner.setLinkType(r.linkType());
        banner.setLinkValue(r.linkValue());
        banner.setSortOrder(r.sortOrder());
        banner.setActive(r.active());
        banner.setStartsAt(r.startsAt());
        banner.setEndsAt(r.endsAt());
    }

    // ----------------------------------------------------- payment methods

    @Transactional(readOnly = true)
    public List<PaymentMethodResponse> paymentMethods() {
        return paymentMethodRepository.findAllByOrderBySortOrderAscIdAsc().stream()
                .map(PaymentMethodResponse::of)
                .toList();
    }

    @Transactional
    public PaymentMethodResponse createPaymentMethod(PaymentMethodUpsertRequest request, User admin) {
        if (paymentMethodRepository.existsByCode(request.code())) {
            throw ApiException.conflict("CODE_TAKEN", "A payment method with that code already exists.");
        }
        PaymentMethod method = new PaymentMethod();
        applyPaymentMethod(method, request);
        PaymentMethod saved = paymentMethodRepository.save(method);
        auditService.record(admin, "PAYMENT_METHOD_CREATED", "PaymentMethod", saved.getId(), saved.getCode());
        return PaymentMethodResponse.of(saved);
    }

    @Transactional
    public PaymentMethodResponse updatePaymentMethod(Long id, PaymentMethodUpsertRequest request, User admin) {
        PaymentMethod method = paymentMethodRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Payment method"));
        if (!method.getCode().equals(request.code()) && paymentMethodRepository.existsByCode(request.code())) {
            throw ApiException.conflict("CODE_TAKEN", "A payment method with that code already exists.");
        }
        applyPaymentMethod(method, request);
        auditService.record(admin, "PAYMENT_METHOD_UPDATED", "PaymentMethod", id, request.code());
        return PaymentMethodResponse.of(paymentMethodRepository.save(method));
    }

    private void applyPaymentMethod(PaymentMethod method, PaymentMethodUpsertRequest r) {
        if (r.maxAmount() < r.minAmount()) {
            throw ApiException.badRequest("INVALID_RANGE", "Maximum amount must be at least the minimum amount.");
        }
        method.setCode(r.code());
        method.setName(r.name());
        method.setAccountName(r.accountName());
        method.setAccountNumber(r.accountNumber());
        method.setLogoUrl(r.logoUrl());
        method.setInstructions(r.instructions());
        method.setInstructionsMy(r.instructionsMy());
        method.setMinAmount(r.minAmount());
        method.setMaxAmount(r.maxAmount());
        method.setSortOrder(r.sortOrder());
        method.setActive(r.active());
        method.setGateway(r.gateway() == null || r.gateway().isBlank() ? null : r.gateway());
    }

    // ------------------------------------------------------------- mapping

    private AdminProductResponse toAdminProduct(Product product) {
        List<ProductVariant> variants = product.getVariants().stream()
                .sorted(Comparator.comparingInt(ProductVariant::getSortOrder).thenComparing(ProductVariant::getId))
                .toList();
        Map<Long, Integer> codeCounts = codeCountsFor(variants);

        return new AdminProductResponse(
                product.getId(), product.getSlug(), product.getName(), product.getNameMy(),
                product.getDescription(), product.getDescriptionMy(), product.getImageUrl(), product.getBannerUrl(),
                product.getInstructions(), product.getInstructionsMy(), product.getFulfillmentType(),
                product.isFeatured(), product.getSortOrder(), product.isActive(),
                product.getSupplierGame(), product.getCategory().getId(), product.getCategory().getName(),
                product.getFields().stream()
                        .map(f -> ProductFieldResponse.of(f, catalogService.parseOptions(f.getOptions())))
                        .toList(),
                variants.stream()
                        .map(v -> toAdminVariant(v, codeCounts.getOrDefault(v.getId(), 0)))
                        .toList());
    }

    /** Re-reads the variant so lazy associations resolve inside a session. */
    @Transactional(readOnly = true)
    public AdminVariantResponse variantResponse(Long variantId) {
        ProductVariant v = variantRepository.findWithProduct(variantId)
                .orElseThrow(() -> ApiException.notFound("Package"));
        int codes = v.getStockType() == StockType.CODE_POOL
                ? (int) stockCodeRepository.countByVariantIdAndStatus(v.getId(), StockCodeStatus.AVAILABLE)
                : 0;
        return toAdminVariant(v, codes);
    }

    private AdminVariantResponse toAdminVariant(ProductVariant v, int availableCodes) {
        return new AdminVariantResponse(
                v.getId(), v.getProduct().getId(), v.getProduct().getName(), v.getSku(), v.getName(), v.getNameMy(),
                v.getBonusText(), v.getDescription(), v.getPrice(), v.getCompareAtPrice(), v.getCostPrice(),
                v.getImageUrl(), v.getStockType(), v.getStockQuantity(), availableCodes,
                v.getLowStockThreshold(), v.getMaxPerOrder(), v.getPopularity(), v.getSortOrder(), v.isActive(),
                v.getSupplier(), v.getSupplierProductId());
    }

    private Map<Long, Integer> codeCountsFor(List<ProductVariant> variants) {
        List<Long> ids = new ArrayList<>(variants.stream()
                .filter(v -> v.getStockType() == StockType.CODE_POOL)
                .map(ProductVariant::getId)
                .toList());
        if (ids.isEmpty()) {
            return Map.of();
        }
        return stockCodeRepository.countAvailableByVariantIds(ids).stream()
                .collect(Collectors.toMap(
                        row -> ((Number) row[0]).longValue(),
                        row -> ((Number) row[1]).intValue()));
    }
}
