package com.diashop.api.service;

import java.nio.charset.StandardCharsets;
import java.util.Optional;
import java.util.Set;

/**
 * Identifies an uploaded image from its leading bytes.
 *
 * The bytes are the only trustworthy input. Browsers and HTTP clients disagree
 * about the declared type — Dio sends every in-memory upload as
 * application/octet-stream — and web file pickers often hand over names with
 * no extension at all. Decoding with ImageIO was no better: the JDK has no
 * reader for WEBP or HEIC, the format an iPhone photo library returns.
 */
final class ImageSignature {

    enum Format {
        JPEG("jpg"), PNG("png"), WEBP("webp"), HEIC("heic");

        final String extension;

        Format(String extension) {
            this.extension = extension;
        }
    }

    static final int HEADER_BYTES = 16;

    private static final Set<String> HEIF_BRANDS = Set.of("heic", "heix", "hevc", "heim", "heis", "mif1", "msf1");

    private ImageSignature() {
    }

    static Optional<Format> detect(byte[] head) {
        if (head == null || head.length < 12) {
            return Optional.empty();
        }
        if (isJpeg(head)) {
            return Optional.of(Format.JPEG);
        }
        if (isPng(head)) {
            return Optional.of(Format.PNG);
        }
        if (isWebp(head)) {
            return Optional.of(Format.WEBP);
        }
        if (isHeif(head)) {
            return Optional.of(Format.HEIC);
        }
        return Optional.empty();
    }

    private static boolean isJpeg(byte[] b) {
        return (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF;
    }

    private static boolean isPng(byte[] b) {
        return (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G'
                && b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A;
    }

    private static boolean isWebp(byte[] b) {
        return ascii(b, 0, 4).equals("RIFF") && ascii(b, 8, 4).equals("WEBP");
    }

    /** ISO base media file: bytes 4-7 are "ftyp", bytes 8-11 the brand. */
    private static boolean isHeif(byte[] b) {
        return ascii(b, 4, 4).equals("ftyp") && HEIF_BRANDS.contains(ascii(b, 8, 4));
    }

    private static String ascii(byte[] b, int offset, int length) {
        return new String(b, offset, length, StandardCharsets.US_ASCII);
    }
}
