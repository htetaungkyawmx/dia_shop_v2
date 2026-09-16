package com.diashop.api.web;

import com.diashop.api.integration.smileone.SmileOneClient;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Lets staff check their Smile.one setup before switching auto delivery on:
 * enter a real player id and confirm the API returns that player's name.
 */
@Tag(name = "Admin · Integrations")
@RestController
@RequestMapping(ApiPaths.ADMIN + "/integrations/smileone")
@RequiredArgsConstructor
public class AdminIntegrationController {

    private final SmileOneClient smileOne;

    @Operation(summary = "Validate a player id against Smile.one (getrole)")
    @PostMapping("/verify")
    public SmileOneClient.Result verify(@RequestBody VerifyRequest request) {
        return smileOne.validatePlayer(request.game(), request.userId(), request.zoneId());
    }

    public record VerifyRequest(@NotBlank String game, @NotBlank String userId, String zoneId) {
    }
}
