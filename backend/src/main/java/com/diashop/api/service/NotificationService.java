package com.diashop.api.service;

import com.diashop.api.common.Json;
import com.diashop.api.domain.Notification;
import com.diashop.api.domain.NotificationType;
import com.diashop.api.domain.User;
import com.diashop.api.dto.MiscDtos.NotificationResponse;
import com.diashop.api.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository repository;
    private final PushSender pushSender;

    @Transactional
    public Notification notify(User user, NotificationType type, String title, String body, Map<String, String> data) {
        Notification notification = new Notification();
        notification.setUser(user);
        notification.setType(type);
        notification.setTitle(title);
        notification.setBody(body);
        notification.setData(Json.write(data));
        Notification saved = repository.save(notification);

        if (user != null) {
            pushSender.sendToUser(user.getId(), title, body, data);
        }
        return saved;
    }

    @Transactional
    public Notification broadcast(NotificationType type, String title, String body, Map<String, String> data) {
        Notification notification = new Notification();
        notification.setUser(null);
        notification.setType(type);
        notification.setTitle(title);
        notification.setBody(body);
        notification.setData(Json.write(data));
        Notification saved = repository.save(notification);
        pushSender.sendToAll(title, body, data);
        return saved;
    }

    @Transactional(readOnly = true)
    public Page<NotificationResponse> list(Long userId, Pageable pageable) {
        return repository.findVisibleForUser(userId, pageable).map(n -> new NotificationResponse(
                n.getId(),
                n.getTitle(),
                n.getBody(),
                n.getType(),
                Json.readStringMap(n.getData()),
                n.getReadAt() != null,
                n.getUser() == null,
                n.getCreatedAt()));
    }

    @Transactional(readOnly = true)
    public long unreadCount(Long userId) {
        return repository.countUnread(userId);
    }

    @Transactional
    public void markRead(Long userId, Long notificationId) {
        repository.findById(notificationId)
                .filter(n -> n.getUser() != null && n.getUser().getId().equals(userId))
                .filter(n -> n.getReadAt() == null)
                .ifPresent(n -> {
                    n.setReadAt(Instant.now());
                    repository.save(n);
                });
    }

    @Transactional
    public void markAllRead(Long userId) {
        repository.markAllRead(userId, Instant.now());
    }
}
