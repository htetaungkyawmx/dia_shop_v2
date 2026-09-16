package com.diashop.api.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * Product and price are snapshotted at purchase time so past orders keep
 * showing what the customer actually bought and paid.
 */
@Getter
@Setter
@Entity
@Table(name = "order_items")
public class OrderItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id")
    private Order order;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "variant_id")
    private ProductVariant variant;

    @Column(name = "product_name", nullable = false, length = 160)
    private String productName;

    @Column(name = "variant_name", nullable = false, length = 160)
    private String variantName;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "unit_price", nullable = false)
    private long unitPrice;

    @Column(nullable = false)
    private int quantity;

    @Column(name = "line_total", nullable = false)
    private long lineTotal;

    /** JSON object keyed by ProductField.fieldKey. */
    @Column(name = "field_values", columnDefinition = "text")
    private String fieldValues;

    @Column(name = "delivered_code", length = 255)
    private String deliveredCode;

    @Column(name = "delivered_secret", length = 255)
    private String deliveredSecret;

    /** Provider order id when this line was delivered through a supplier API. */
    @Column(name = "supplier_order_id", length = 120)
    private String supplierOrderId;
}
