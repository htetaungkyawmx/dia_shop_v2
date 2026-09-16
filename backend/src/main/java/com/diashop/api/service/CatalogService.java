package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.common.SearchPattern;
import com.diashop.api.common.Json;
import com.diashop.api.domain.Product;
import com.diashop.api.domain.ProductField;
import com.diashop.api.domain.ProductVariant;
import com.diashop.api.dto.CatalogDtos.BannerResponse;
import com.diashop.api.dto.CatalogDtos.CategoryResponse;
import com.diashop.api.dto.CatalogDtos.HomeResponse;
import com.diashop.api.dto.CatalogDtos.ProductDetailResponse;
import com.diashop.api.dto.CatalogDtos.ProductFieldResponse;
import com.diashop.api.dto.CatalogDtos.ProductSummaryResponse;
import com.diashop.api.dto.CatalogDtos.VariantResponse;
import com.diashop.api.repository.BannerRepository;
import com.diashop.api.repository.CategoryRepository;
import com.diashop.api.repository.ProductRepository;
import com.diashop.api.repository.ProductVariantRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

/** Read-only catalog for the user app and website. */
@Service
@RequiredArgsConstructor
public class CatalogService {

    /** Remaining units are only revealed once stock gets this low. */
    private static final int SHOW_REMAINING_BELOW = 10;

    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final ProductVariantRepository variantRepository;
    private final BannerRepository bannerRepository;
    private final StockService stockService;
    private final SettingsService settingsService;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public HomeResponse home() {
        List<BannerResponse> banners = bannerRepository.findVisible(Instant.now()).stream()
                .map(BannerResponse::of)
                .toList();
        List<CategoryResponse> categories = categoryRepository.findByActiveTrueOrderBySortOrderAscIdAsc().stream()
                .map(CategoryResponse::of)
                .toList();
        List<ProductSummaryResponse> featured =
                toSummaries(productRepository.findByActiveTrueAndFeaturedTrueOrderBySortOrderAscIdAsc());

        return new HomeResponse(
                banners,
                categories,
                featured,
                settingsService.getBoolean(SettingsService.MAINTENANCE, false),
                settingsService.get(SettingsService.MAINTENANCE_MESSAGE, ""));
    }

    @Transactional(readOnly = true)
    public List<CategoryResponse> categories() {
        return categoryRepository.findByActiveTrueOrderBySortOrderAscIdAsc().stream()
                .map(CategoryResponse::of)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ProductSummaryResponse> products(String categorySlug, String query) {
        return toSummaries(productRepository.findPublic(
                SearchPattern.orBlank(categorySlug), SearchPattern.of(query)));
    }

    @Transactional(readOnly = true)
    public ProductDetailResponse product(String slug) {
        Product product = productRepository.findBySlug(slug)
                .filter(Product::isActive)
                .orElseThrow(() -> ApiException.notFound("Product"));

        List<ProductVariant> variants = product.getVariants().stream()
                .filter(ProductVariant::isActive)
                .sorted(Comparator.comparingInt(ProductVariant::getSortOrder)
                        .thenComparing(ProductVariant::getId))
                .toList();
        Map<Long, Integer> availability = stockService.availabilityFor(variants);

        return new ProductDetailResponse(
                product.getId(),
                product.getSlug(),
                product.getName(),
                product.getNameMy(),
                product.getDescription(),
                product.getDescriptionMy(),
                product.getImageUrl(),
                product.getBannerUrl(),
                product.getInstructions(),
                product.getInstructionsMy(),
                product.getFulfillmentType(),
                CategoryResponse.of(product.getCategory()),
                product.getFields().stream().map(this::toFieldResponse).toList(),
                variants.stream().map(v -> toVariantResponse(v, availability.getOrDefault(v.getId(), 0))).toList());
    }

    private List<ProductSummaryResponse> toSummaries(List<Product> products) {
        if (products.isEmpty()) {
            return List.of();
        }
        List<ProductVariant> allVariants = products.stream()
                .flatMap(p -> variantRepository.findByProductIdOrderBySortOrderAscIdAsc(p.getId()).stream())
                .filter(ProductVariant::isActive)
                .toList();
        Map<Long, Integer> availability = stockService.availabilityFor(allVariants);

        return products.stream().map(product -> {
            List<ProductVariant> variants = allVariants.stream()
                    .filter(v -> v.getProduct().getId().equals(product.getId()))
                    .toList();
            Long startingPrice = variants.stream()
                    .mapToLong(ProductVariant::getPrice)
                    .min()
                    .stream().boxed().findFirst().orElse(null);
            boolean inStock = variants.stream()
                    .anyMatch(v -> availability.getOrDefault(v.getId(), 0) > 0);

            return new ProductSummaryResponse(
                    product.getId(),
                    product.getSlug(),
                    product.getName(),
                    product.getNameMy(),
                    product.getImageUrl(),
                    product.getCategory().getSlug(),
                    product.isFeatured(),
                    product.getFulfillmentType(),
                    startingPrice,
                    inStock);
        }).toList();
    }

    private VariantResponse toVariantResponse(ProductVariant v, int available) {
        boolean inStock = available > 0;
        Integer remaining = (available < SHOW_REMAINING_BELOW && !v.isUnlimited()) ? available : null;
        Long compareAt = (v.getCompareAtPrice() != null && v.getCompareAtPrice() > v.getPrice())
                ? v.getCompareAtPrice()
                : null;

        return new VariantResponse(
                v.getId(), v.getSku(), v.getName(), v.getNameMy(), v.getBonusText(), v.getDescription(),
                v.getPrice(), compareAt, v.getImageUrl(), v.getMaxPerOrder(), v.getPopularity(),
                inStock, remaining);
    }

    private ProductFieldResponse toFieldResponse(ProductField field) {
        return ProductFieldResponse.of(field, parseOptions(field.getOptions()));
    }

    List<String> parseOptions(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {
            });
        } catch (Exception e) {
            return List.of();
        }
    }

    String writeOptions(List<String> options) {
        return (options == null || options.isEmpty()) ? null : Json.write(options);
    }
}
