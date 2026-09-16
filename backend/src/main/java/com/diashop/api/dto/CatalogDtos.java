package com.diashop.api.dto;

import com.diashop.api.domain.Banner;
import com.diashop.api.domain.BannerLinkType;
import com.diashop.api.domain.Category;
import com.diashop.api.domain.FieldInputType;
import com.diashop.api.domain.FulfillmentType;
import com.diashop.api.domain.Product;
import com.diashop.api.domain.ProductField;
import com.diashop.api.domain.StockType;

import java.util.List;

public final class CatalogDtos {

    private CatalogDtos() {
    }

    public record CategoryResponse(
            Long id, String slug, String name, String nameMy, String iconUrl, int sortOrder, boolean active
    ) {
        public static CategoryResponse of(Category c) {
            return new CategoryResponse(c.getId(), c.getSlug(), c.getName(), c.getNameMy(),
                    c.getIconUrl(), c.getSortOrder(), c.isActive());
        }
    }

    public record ProductSummaryResponse(
            Long id, String slug, String name, String nameMy, String imageUrl,
            String categorySlug, boolean featured, FulfillmentType fulfillmentType,
            Long startingPrice, boolean inStock
    ) {
    }

    public record ProductFieldResponse(
            Long id, String key, String label, String labelMy, String placeholder, String helpText,
            FieldInputType inputType, List<String> options, String validationRegex, boolean required
    ) {
        public static ProductFieldResponse of(ProductField f, List<String> options) {
            return new ProductFieldResponse(f.getId(), f.getFieldKey(), f.getLabel(), f.getLabelMy(),
                    f.getPlaceholder(), f.getHelpText(), f.getInputType(), options,
                    f.getValidationRegex(), f.isRequired());
        }
    }

    /**
     * Stock is exposed as a coarse availability state plus a remaining count
     * only when it is low, so competitors cannot read the full inventory.
     */
    public record VariantResponse(
            Long id, String sku, String name, String nameMy, String bonusText, String description,
            long price, Long compareAtPrice, String imageUrl, int maxPerOrder, int popularity,
            boolean inStock, Integer remaining
    ) {
    }

    public record ProductDetailResponse(
            Long id, String slug, String name, String nameMy, String description, String descriptionMy,
            String imageUrl, String bannerUrl, String instructions, String instructionsMy,
            FulfillmentType fulfillmentType, CategoryResponse category,
            List<ProductFieldResponse> fields, List<VariantResponse> variants
    ) {
    }

    public record BannerResponse(
            Long id, String title, String imageUrl, BannerLinkType linkType, String linkValue
    ) {
        public static BannerResponse of(Banner b) {
            return new BannerResponse(b.getId(), b.getTitle(), b.getImageUrl(), b.getLinkType(), b.getLinkValue());
        }
    }

    public record HomeResponse(
            List<BannerResponse> banners,
            List<CategoryResponse> categories,
            List<ProductSummaryResponse> featured,
            boolean maintenance,
            String maintenanceMessage
    ) {
    }

    /** Admin view: full stock and cost, never returned to the user app. */
    public record AdminVariantResponse(
            Long id, Long productId, String productName, String sku, String name, String nameMy,
            String bonusText, String description, long price, Long compareAtPrice, long costPrice,
            String imageUrl, StockType stockType, int stockQuantity, int availableCodes,
            int lowStockThreshold, int maxPerOrder, int popularity, int sortOrder, boolean active,
            String supplier, String supplierProductId
    ) {
    }

    public record AdminProductResponse(
            Long id, String slug, String name, String nameMy, String description, String descriptionMy,
            String imageUrl, String bannerUrl, String instructions, String instructionsMy,
            FulfillmentType fulfillmentType, boolean featured, int sortOrder, boolean active,
            String supplierGame, Long categoryId, String categoryName,
            List<ProductFieldResponse> fields, List<AdminVariantResponse> variants
    ) {
    }
}
