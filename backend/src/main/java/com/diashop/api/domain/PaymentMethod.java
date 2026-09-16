package com.diashop.api.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "payment_methods")
public class PaymentMethod extends BaseEntity {

    @Column(nullable = false, length = 40)
    private String code;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(name = "account_name", nullable = false, length = 120)
    private String accountName;

    @Column(name = "account_number", nullable = false, length = 80)
    private String accountNumber;

    @Column(name = "logo_url", length = 500)
    private String logoUrl;

    @Column(columnDefinition = "text")
    private String instructions;

    @Column(name = "instructions_my", columnDefinition = "text")
    private String instructionsMy;

    @Column(name = "min_amount", nullable = false)
    private long minAmount = 1000L;

    @Column(name = "max_amount", nullable = false)
    private long maxAmount = 5_000_000L;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder = 0;

    @Column(nullable = false)
    private boolean active = true;

    /**
     * Null for a manual bank/wallet transfer. Set to a gateway key (KBZPAY,
     * TWOCTWOP, STRIPE) once an online gateway backs this method; PaymentGateway
     * implementations are resolved by this value.
     */
    @Column(length = 30)
    private String gateway;
}
