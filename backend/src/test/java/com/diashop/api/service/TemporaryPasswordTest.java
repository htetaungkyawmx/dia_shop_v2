package com.diashop.api.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class TemporaryPasswordTest {

    @Test
    @DisplayName("always satisfies the sign-up password rule, so the user can sign in with it")
    void meetsPasswordRule() {
        for (int i = 0; i < 500; i++) {
            // Same rule as RegisterRequest / ChangePasswordRequest.
            assertThat(TemporaryPassword.generate())
                    .hasSizeGreaterThanOrEqualTo(8)
                    .matches("^(?=.*[A-Za-z])(?=.*\\d).+$");
        }
    }

    @Test
    @DisplayName("never contains characters that are misread when dictated")
    void avoidsAmbiguousCharacters() {
        for (int i = 0; i < 500; i++) {
            assertThat(TemporaryPassword.generate()).doesNotContainPattern("[0O1lI]");
        }
    }

    @Test
    @DisplayName("is different every time")
    void isRandom() {
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < 1000; i++) {
            seen.add(TemporaryPassword.generate());
        }
        assertThat(seen).hasSize(1000);
    }
}
