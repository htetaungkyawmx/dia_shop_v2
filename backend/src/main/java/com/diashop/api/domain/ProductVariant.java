package com.diashop.api.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import lombok.Getter;
import lombok.Setter;

/** One buyable package: "86 Diamonds", "60 UC", "Netflix 1 Month". */
@Getter
@Setter
@Entity
@Table(name = "product_variants")
public class ProductVariant extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id")
    private Product product;

    @Column(nullable = false, length = 80)
    private String sku;

    @Column(nullable = false, length = 160)
    private String name;

    @Column(name = "name_my", length = 160)
    private String nameMy;

    @Column(name = "bonus_text", length = 80)
    private String bonusText;

    @Column(length = 255)
    private String description;

    @Column(nullable = false)
    private long price;

    /** Struck-through "was" price. Only shown when higher than price. */
    @Column(name = "compare_at_price")
    private Long compareAtPrice;

    /** Never exposed to the user app; drives the admin profit report. */
    @Column(name = "cost_price", nullable = false)
    private long costPrice = 0L;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "stock_type", nullable = false, length = 20)
    private StockType stockType = StockType.UNLIMITED;

    @Column(name = "stock_quantity", nullable = false)
    private int stockQuantity = 0;

    @Column(name = "low_stock_threshold", nullable = false)
    private int lowStockThreshold = 5;

    @Column(name = "max_per_order", nullable = false)
    private int maxPerOrder = 10;

    @Column(nullable = false)
    private int popularity = 0;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder = 0;

    @Column(nullable = false)
    private boolean active = true;

    @Version
    @Column(nullable = false)
    private long version;

    /** CODE_POOL stock lives in stock_codes, so this counter does not apply. */
    public boolean tracksQuantity() {
        return stockType == StockType.LIMITED;
    }

    public boolean isUnlimited() {
        return stockType == StockType.UNLIMITED;
    }
}
