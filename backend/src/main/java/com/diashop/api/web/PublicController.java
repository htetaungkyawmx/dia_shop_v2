package com.diashop.api.web;

import com.diashop.api.dto.CatalogDtos.CategoryResponse;
import com.diashop.api.dto.CatalogDtos.HomeResponse;
import com.diashop.api.dto.CatalogDtos.ProductDetailResponse;
import com.diashop.api.dto.CatalogDtos.ProductSummaryResponse;
import com.diashop.api.dto.MiscDtos.AppConfigResponse;
import com.diashop.api.dto.WalletDtos.PaymentMethodResponse;
import com.diashop.api.service.CatalogService;
import com.diashop.api.service.SettingsService;
import com.diashop.api.service.TopupService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** Everything a signed-out visitor may read. */
@Tag(name = "Public catalog")
@RestController
@RequestMapping(ApiPaths.PUBLIC)
@RequiredArgsConstructor
public class PublicController {

    private final CatalogService catalogService;
    private final SettingsService settingsService;
    private final TopupService topupService;

    @Operation(summary = "Home screen payload: banners, categories and featured products")
    @GetMapping("/home")
    public HomeResponse home() {
        return catalogService.home();
    }

    @GetMapping("/categories")
    public List<CategoryResponse> categories() {
        return catalogService.categories();
    }

    @GetMapping("/products")
    public List<ProductSummaryResponse> products(@RequestParam(required = false) String category,
                                                 @RequestParam(required = false) String q) {
        return catalogService.products(category, q);
    }

    @GetMapping("/products/{slug}")
    public ProductDetailResponse product(@PathVariable String slug) {
        return catalogService.product(slug);
    }

    @GetMapping("/payment-methods")
    public List<PaymentMethodResponse> paymentMethods() {
        return topupService.activePaymentMethods();
    }

    @Operation(summary = "Shop name, maintenance flag, top-up limits and support links")
    @GetMapping("/config")
    public AppConfigResponse config() {
        return new AppConfigResponse(
                settingsService.get(SettingsService.APP_NAME, "Dia Shop"),
                settingsService.getBoolean(SettingsService.MAINTENANCE, false),
                settingsService.get(SettingsService.MAINTENANCE_MESSAGE, ""),
                settingsService.getLong(SettingsService.TOPUP_MIN, 1000),
                settingsService.getLong(SettingsService.TOPUP_MAX, 5_000_000),
                settingsService.withPrefix("support."));
    }
}
