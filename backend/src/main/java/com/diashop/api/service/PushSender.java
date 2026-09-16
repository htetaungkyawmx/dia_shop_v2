package com.diashop.api.service;

import com.diashop.api.repository.DeviceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

/**
 * Push delivery seam.
 *
 * Notifications are always persisted (the in-app bell works regardless); this
 * only handles the optional device push. Wire Firebase Admin SDK or any other
 * provider here — nothing else in the app needs to change.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PushSender {

    private final DeviceRepository deviceRepository;

    @Transactional(readOnly = true)
    public void sendToUser(Long userId, String title, String body, Map<String, String> data) {
        var tokens = deviceRepository.findByUserId(userId);
        if (tokens.isEmpty()) {
            return;
        }
        log.debug("Push to user {} ({} device(s)): {}", userId, tokens.size(), title);
    }

    public void sendToAll(String title, String body, Map<String, String> data) {
        log.debug("Broadcast push: {}", title);
    }
}
