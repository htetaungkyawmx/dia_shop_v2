package com.diashop.api.common;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

class SearchPatternTest {

    @ParameterizedTest
    @NullSource
    @ValueSource(strings = {"", "   "})
    @DisplayName("an absent search term matches every row instead of binding a null")
    void blankTermMatchesEverything(String term) {
        assertThat(SearchPattern.of(term)).isEqualTo("%");
    }

    @Test
    @DisplayName("a term is lowercased and wrapped for a contains match")
    void wrapsTermForContainsMatch() {
        assertThat(SearchPattern.of("  Buyer@Test.com ")).isEqualTo("%buyer@test.com%");
    }

    @Test
    @DisplayName("wildcards typed by a user are stripped, not treated as operators")
    void stripsWildcards() {
        assertThat(SearchPattern.of("100%_off")).isEqualTo("%100off%");
        assertThat(SearchPattern.of("a\\b")).isEqualTo("%ab%");
    }

    @Test
    @DisplayName("a term made only of wildcards degrades to match-all rather than an empty pattern")
    void wildcardOnlyTermMatchesEverything() {
        assertThat(SearchPattern.of("%%%")).isEqualTo("%");
    }

    @Test
    @DisplayName("an optional exact filter becomes a blank string, never null")
    void orBlankNeverReturnsNull() {
        assertThat(SearchPattern.orBlank(null)).isEmpty();
        assertThat(SearchPattern.orBlank("  mobile-games ")).isEqualTo("mobile-games");
    }
}
