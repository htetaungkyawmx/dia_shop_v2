package com.diashop.api.service;

import com.diashop.api.config.AppProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

/**
 * Human-friendly, non-sequential reference, e.g. DS-260916-7F3K2QW.
 *
 * Seven characters from a 32-symbol alphabet give ~34 billion combinations per
 * day, so a same-day collision is vanishingly rare; the unique index on
 * order_no plus one retry in OrderService covers the remainder.
 */
@Component
@RequiredArgsConstructor
public class OrderNumberGenerator {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("yyMMdd");
    // No I, O, 0 or 1: they are misread when a customer reads the number aloud.
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final int SUFFIX_LENGTH = 7;

    private final AppProperties props;
    private final SecureRandom random = new SecureRandom();

    public String nextOrderNo() {
        return build(props.order().numberPrefix());
    }

    public String nextTopupNo() {
        return build("TP");
    }

    private String build(String prefix) {
        StringBuilder suffix = new StringBuilder(SUFFIX_LENGTH);
        for (int i = 0; i < SUFFIX_LENGTH; i++) {
            suffix.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
        }
        return prefix + "-" + LocalDate.now().format(DATE) + "-" + suffix;
    }
}
