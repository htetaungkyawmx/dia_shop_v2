package com.diashop.api.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** A value the buyer must supply for this product, e.g. Player ID or Server. */
@Getter
@Setter
@Entity
@Table(name = "product_fields")
public class ProductField {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id")
    private Product product;

    @Column(name = "field_key", nullable = false, length = 50)
    private String fieldKey;

    @Column(nullable = false, length = 120)
    private String label;

    @Column(name = "label_my", length = 120)
    private String labelMy;

    @Column(length = 160)
    private String placeholder;

    @Column(name = "help_text", length = 255)
    private String helpText;

    @Enumerated(EnumType.STRING)
    @Column(name = "input_type", nullable = false, length = 20)
    private FieldInputType inputType = FieldInputType.TEXT;

    /** JSON array of allowed values when inputType is SELECT. */
    @Column(columnDefinition = "text")
    private String options;

    @Column(name = "validation_regex", length = 255)
    private String validationRegex;

    @Column(nullable = false)
    private boolean required = true;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder = 0;
}
