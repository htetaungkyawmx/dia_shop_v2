package com.diashop.api.common;

import java.time.Instant;
import java.util.Map;

public record ErrorResponse(
        String code,
        String message,
        Map<String, String> fieldErrors,
        String path,
        Instant timestamp
) {
    public static ErrorResponse of(String code, String message, String path) {
        return new ErrorResponse(code, message, null, path, Instant.now());
    }

    public static ErrorResponse withFields(String code, String message, Map<String, String> fieldErrors, String path) {
        return new ErrorResponse(code, message, fieldErrors, path, Instant.now());
    }
}
