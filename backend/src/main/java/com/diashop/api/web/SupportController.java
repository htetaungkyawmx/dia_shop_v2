package com.diashop.api.web;

import com.diashop.api.common.PageResponse;
import com.diashop.api.dto.MiscDtos.CreateTicketRequest;
import com.diashop.api.dto.MiscDtos.TicketResponse;
import com.diashop.api.security.AuthUser;
import com.diashop.api.security.CurrentUser;
import com.diashop.api.service.SupportService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.function.Function;

@Tag(name = "Support")
@RestController
@RequestMapping(ApiPaths.API + "/support")
@RequiredArgsConstructor
public class SupportController {

    private final SupportService supportService;

    @PostMapping("/tickets")
    public ResponseEntity<TicketResponse> create(@CurrentUser AuthUser principal,
                                                 @Valid @RequestBody CreateTicketRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(supportService.create(principal.id(), request));
    }

    @GetMapping("/tickets")
    public PageResponse<TicketResponse> list(@CurrentUser AuthUser principal,
                                             @RequestParam(defaultValue = "0") int page,
                                             @RequestParam(defaultValue = "20") int size) {
        return PageResponse.from(
                supportService.listForUser(principal.id(), PageRequests.of(page, size)),
                Function.identity());
    }
}
