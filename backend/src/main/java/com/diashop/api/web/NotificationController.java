package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.dto.MiscDtos.NotificationResponse;
import com.diashop.api.dto.MiscDtos.SimpleMessage;
import com.diashop.api.dto.MiscDtos.UnreadCountResponse;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.NotificationService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.function.Function;

@Tag(name = "Notifications")
@RestController
@RequestMapping(ApiPaths.API + "/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    public PageResponse<NotificationResponse> list(@CurrentUser AuthUser principal,
                                                   @RequestParam(defaultValue = "0") int page,
                                                   @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                notificationService.list(principal.id(), PageRequests.of(page, size)),
                Function.identity());
    }

    @GetMapping("/unread-count")
    public UnreadCountResponse unreadCount(@CurrentUser AuthUser principal) {
        return new UnreadCountResponse(notificationService.unreadCount(principal.id()));
    }

    @PostMapping("/{id}/read")
    public SimpleMessage markRead(@CurrentUser AuthUser principal, @PathVariable Long id) {
        notificationService.markRead(principal.id(), id);
        return SimpleMessage.of("Marked as read.");
    }

    @PostMapping("/read-all")
    public SimpleMessage markAllRead(@CurrentUser AuthUser principal) {
        notificationService.markAllRead(principal.id());
        return SimpleMessage.of("All notifications marked as read.");
    }
}
