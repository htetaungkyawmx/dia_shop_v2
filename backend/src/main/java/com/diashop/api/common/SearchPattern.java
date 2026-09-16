package com.diashop.api.common;

import java.util.Locale;

/**
 * Builds the LIKE pattern used by every admin search.
 *
 * Searches bind a pattern rather than a nullable term on purpose: PostgreSQL
 * cannot infer the type of a bare null inside {@code lower(? || '%')}, which
 * fails at runtime with "function lower(bytea) does not exist". A pattern is
 * always a non-null string, and the LIKE operand gives it a type.
 */
public final class SearchPattern {

    /** Matches every row, used when no search term was given. */
    public static final String MATCH_ALL = "%";

    private SearchPattern() {
    }

    public static String of(String term) {
        if (term == null || term.isBlank()) {
            return MATCH_ALL;
        }
        // Wildcards are stripped rather than escaped: Hibernate emits LIKE
        // without an ESCAPE clause, so a backslash would be matched literally.
        String cleaned = term.trim()
                .toLowerCase(Locale.ROOT)
                .replace("\\", "")
                .replace("%", "")
                .replace("_", "");
        return cleaned.isEmpty() ? MATCH_ALL : "%" + cleaned + "%";
    }

    /** Blank-safe value for an optional exact-match filter. */
    public static String orBlank(String value) {
        return value == null ? "" : value.trim();
    }
}
