package com.diashop.api.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;

class ImageSignatureTest {

    /** Builds a 16-byte header: a 4-byte box size, then the given ASCII text. */
    private static byte[] isoBox(String typeAndBrand) {
        byte[] head = new byte[16];
        head[3] = 0x18;
        byte[] text = typeAndBrand.getBytes(StandardCharsets.US_ASCII);
        System.arraycopy(text, 0, head, 4, text.length);
        return head;
    }

    private static byte[] padded(byte... head) {
        return Arrays.copyOf(head, 16);
    }

    @Test
    @DisplayName("accepts JPEG and PNG")
    void acceptsCommonFormats() {
        assertThat(ImageSignature.detect(padded((byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0)))
                .contains(ImageSignature.Format.JPEG);
        assertThat(ImageSignature.detect(padded((byte) 0x89, (byte) 'P', (byte) 'N', (byte) 'G',
                (byte) 0x0D, (byte) 0x0A, (byte) 0x1A, (byte) 0x0A))).contains(ImageSignature.Format.PNG);
    }

    @Test
    @DisplayName("accepts a real WEBP file, which ImageIO cannot decode")
    void acceptsWebp() {
        byte[] webp = Base64.getDecoder().decode("UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==");
        assertThat(ImageSignature.detect(Arrays.copyOf(webp, 16))).contains(ImageSignature.Format.WEBP);
    }

    @Test
    @DisplayName("accepts HEIC, the format an iPhone photo library returns")
    void acceptsHeic() {
        assertThat(ImageSignature.detect(isoBox("ftypheic"))).contains(ImageSignature.Format.HEIC);
        assertThat(ImageSignature.detect(isoBox("ftypmif1"))).contains(ImageSignature.Format.HEIC);
    }

    @Test
    @DisplayName("rejects a non-image renamed to look like one")
    void rejectsImpostors() {
        assertThat(ImageSignature.detect(padded("%PDF-1.7".getBytes(StandardCharsets.US_ASCII)))).isEmpty();
        assertThat(ImageSignature.detect(padded("#!/bin/sh".getBytes(StandardCharsets.US_ASCII)))).isEmpty();
        // An MP4 is also an ftyp container, but not an image brand.
        assertThat(ImageSignature.detect(isoBox("ftypisom"))).isEmpty();
    }

    @Test
    @DisplayName("rejects files too short to carry a signature")
    void rejectsTruncated() {
        assertThat(ImageSignature.detect(new byte[]{(byte) 0xFF, (byte) 0xD8})).isEmpty();
        assertThat(ImageSignature.detect(null)).isEmpty();
    }
}
