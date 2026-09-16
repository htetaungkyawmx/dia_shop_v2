package com.diashop.api.integration.smileone;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.diashop.api.service.SettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.Map;
import java.util.TreeMap;

/**
 * Talks to the Smile.one reseller ("smilecoding") API: validate a player and
 * place a top-up order. Credentials live in app_settings so staff can paste in
 * their reseller key from the admin panel without a redeploy.
 *
 * Signing follows Smile.one's documented scheme: take every request field
 * except the signature, sort by key, join as {@code k=v&k=v&...}, append the
 * secret key, then MD5 the result twice. This is isolated here and covered by
 * {@code SmileOneClientTest} so it can be checked against a live key on the
 * first real order and adjusted in one place if the provider ever changes it.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SmileOneClient {

    private final SettingsService settings;
    private final ObjectMapper mapper = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15))
            .build();

    public boolean isEnabled() {
        return settings.getBoolean("smileone.enabled", false)
                && !settings.get("smileone.key", "").isBlank()
                && !settings.get("smileone.uid", "").isBlank();
    }

    /** Confirms the player id (and server, when the game needs one) exists. */
    public Result validatePlayer(String game, String userId, String zoneId) {
        return post("getrole", baseParams(game, userId, zoneId));
    }

    /** Places the top-up. productId is the Smile.one package id for the variant. */
    public Result createOrder(String game, String productId, String userId, String zoneId) {
        TreeMap<String, String> params = baseParams(game, userId, zoneId);
        params.put("productid", productId);
        return post("createorder", params);
    }

    private TreeMap<String, String> baseParams(String game, String userId, String zoneId) {
        TreeMap<String, String> params = new TreeMap<>();
        params.put("uid", settings.get("smileone.uid", ""));
        params.put("email", settings.get("smileone.email", ""));
        params.put("product", game == null ? "" : game);
        params.put("userid", userId == null ? "" : userId);
        params.put("zoneid", zoneId == null || zoneId.isBlank() ? "0" : zoneId);
        params.put("time", String.valueOf(System.currentTimeMillis() / 1000));
        return params;
    }

    private Result post(String action, TreeMap<String, String> params) {
        params.put("sign", sign(params, settings.get("smileone.key", "")));
        String base = settings.get("smileone.base_url", "https://www.smile.one").replaceAll("/+$", "");
        String region = settings.get("smileone.region", "br").trim();
        String url = base + "/" + region + "/smilecoding/api/" + action;
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .timeout(Duration.ofSeconds(30))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .header("Accept", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(formEncode(params)))
                    .build();
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            return parse(action, response.body());
        } catch (Exception e) {
            log.warn("Smile.one {} call failed: {}", action, e.toString());
            return Result.error("Could not reach Smile.one: " + e.getMessage());
        }
    }

    private Result parse(String action, String body) {
        try {
            JsonNode node = mapper.readTree(body);
            int status = node.path("status").asInt(0);
            boolean ok = status == 200;
            String name = firstText(node, "username", "nickname", "role", "name");
            String orderId = firstText(node, "order_id", "orderid", "order", "game_order");
            String message = firstText(node, "message", "error", "msg");
            if (ok) {
                return new Result(true, name, orderId, message == null ? "OK" : message, body);
            }
            log.warn("Smile.one {} returned status {}: {}", action, status, body);
            return new Result(false, name, orderId,
                    message == null || message.isBlank() ? "Smile.one returned status " + status : message, body);
        } catch (Exception e) {
            log.warn("Smile.one {} gave an unreadable response: {}", action, body);
            return Result.error("Unexpected response from Smile.one");
        }
    }

    private static String firstText(JsonNode node, String... keys) {
        for (String key : keys) {
            JsonNode value = node.get(key);
            if (value != null && !value.isNull() && !value.asText().isBlank()) {
                return value.asText();
            }
        }
        return null;
    }

    /** md5(md5( sorted "k=v&..." + secretKey )). Package-visible for the test. */
    static String sign(Map<String, String> params, String secretKey) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> e : new TreeMap<>(params).entrySet()) {
            if ("sign".equals(e.getKey())) {
                continue;
            }
            sb.append(e.getKey()).append('=').append(e.getValue() == null ? "" : e.getValue()).append('&');
        }
        sb.append(secretKey);
        return md5(md5(sb.toString()));
    }

    private static String md5(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(digest.length * 2);
            for (byte b : digest) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16));
                hex.append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (Exception e) {
            throw new IllegalStateException("MD5 unavailable", e);
        }
    }

    private static String formEncode(Map<String, String> params) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> e : params.entrySet()) {
            if (sb.length() > 0) {
                sb.append('&');
            }
            sb.append(URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8))
              .append('=')
              .append(URLEncoder.encode(e.getValue() == null ? "" : e.getValue(), StandardCharsets.UTF_8));
        }
        return sb.toString();
    }

    /** Outcome of a Smile.one call. rawBody is kept for the admin audit trail. */
    public record Result(boolean success, String playerName, String orderId, String message, String rawBody) {
        static Result error(String message) {
            return new Result(false, null, null, message, null);
        }
    }
}
