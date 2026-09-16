package com.diashop.api.service;

import com.diashop.api.config.AppProperties;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class OrderNumberGeneratorTest {

    private final OrderNumberGenerator generator = new OrderNumberGenerator(new AppProperties(
            new AppProperties.Jwt("test-secret-that-is-at-least-32-bytes-long", "dia-shop",
                    Duration.ofMinutes(30), Duration.ofDays(30)),
            new AppProperties.Cors(List.of("*")),
            new AppProperties.Storage("local", "./uploads", "http://localhost:8080/uploads"),
            new AppProperties.Admin("admin@test.com", "Admin@12345", "Admin"),
            new AppProperties.Order("DS"),
            new AppProperties.Google(List.of())));

    @Test
    @DisplayName("order numbers carry the prefix and today's date")
    void formatsOrderNumber() {
        String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyMMdd"));

        assertThat(generator.nextOrderNo())
                .startsWith("DS-" + today + "-")
                .hasSize(3 + 6 + 1 + 7);
    }

    @Test
    @DisplayName("top-up numbers use their own prefix so the two never collide")
    void formatsTopupNumber() {
        assertThat(generator.nextTopupNo()).startsWith("TP-");
        assertThat(generator.nextOrderNo()).doesNotStartWith("TP-");
    }

    @Test
    @DisplayName("the suffix omits characters a customer would misread aloud")
    void avoidsAmbiguousCharacters() {
        for (int i = 0; i < 500; i++) {
            String suffix = generator.nextOrderNo().substring(10);
            assertThat(suffix).doesNotContain("I").doesNotContain("O")
                    .doesNotContain("0").doesNotContain("1");
        }
    }

    @Test
    @DisplayName("numbers are effectively unique across a large batch")
    void producesDistinctNumbers() {
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < 2_000; i++) {
            seen.add(generator.nextOrderNo());
        }
        // 32^7 (~34 billion) combinations: at 2k draws the chance of even one
        // collision is under 1 in 10,000, so a duplicate here means the
        // randomness is broken rather than unlucky.
        assertThat(seen).hasSize(2_000);
    }
}
