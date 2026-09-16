package com.diashop.api.service;

import java.security.SecureRandom;

/** Readable one-time passwords that still satisfy the sign-up password rule. */
final class TemporaryPassword {

    // No 0/O, 1/l/I: the password is read out to a customer over chat or phone.
    private static final String LETTERS = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
    private static final String DIGITS = "23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    private TemporaryPassword() {
    }

    static String generate() {
        StringBuilder out = new StringBuilder(10);
        for (int i = 0; i < 7; i++) {
            out.append(LETTERS.charAt(RANDOM.nextInt(LETTERS.length())));
        }
        for (int i = 0; i < 3; i++) {
            out.append(DIGITS.charAt(RANDOM.nextInt(DIGITS.length())));
        }
        return out.toString();
    }
}
