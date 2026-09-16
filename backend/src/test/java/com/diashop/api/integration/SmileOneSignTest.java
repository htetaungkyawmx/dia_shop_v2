package com.diashop.api.integration;

import com.diashop.api.integration.smileone.SmileOneClient;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;
import java.security.MessageDigest;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeMap;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Pins the Smile.one signature algorithm so it stays reproducible: fields are
 * sorted by key, joined as k=v&..., the secret key is appended, and the whole
 * string is MD5'd twice. Insensitive to the order fields are supplied in.
 */
class SmileOneSignTest {

    private static String sign(Map<String, String> params, String key) throws Exception {
        Method m = SmileOneClient.class.getDeclaredMethod("sign", Map.class, String.class);
        m.setAccessible(true);
        return (String) m.invoke(null, params, key);
    }

    private static String md5(String in) throws Exception {
        byte[] d = MessageDigest.getInstance("MD5").digest(in.getBytes("UTF-8"));
        StringBuilder h = new StringBuilder();
        for (byte b : d) {
            h.append(Character.forDigit((b >> 4) & 0xF, 16)).append(Character.forDigit(b & 0xF, 16));
        }
        return h.toString();
    }

    @Test
    void signMatchesSortedDoubleMd5() throws Exception {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("uid", "123");
        params.put("email", "shop@example.com");
        params.put("product", "mobilelegends");
        params.put("userid", "555");
        params.put("zoneid", "2005");
        params.put("time", "1700000000");

        String expected = md5(md5(
                "email=shop@example.com&product=mobilelegends&time=1700000000"
                        + "&uid=123&userid=555&zoneid=2005&SECRET"));

        assertThat(sign(params, "SECRET")).isEqualTo(expected);
    }

    @Test
    void signIgnoresInputOrderAndExistingSign() throws Exception {
        Map<String, String> a = new TreeMap<>();
        a.put("b", "2");
        a.put("a", "1");
        Map<String, String> b = new LinkedHashMap<>();
        b.put("a", "1");
        b.put("b", "2");
        b.put("sign", "stale");   // must be excluded from the signature

        assertThat(sign(a, "K")).isEqualTo(sign(b, "K"));
    }
}
