package com.diashop.api.web;

import com.diashop.api.dto.MiscDtos.UploadResponse;
import com.diashop.api.service.StorageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "Uploads")
@RestController
@RequestMapping(ApiPaths.API + "/uploads")
@RequiredArgsConstructor
public class UploadController {

    private final StorageService storageService;

    @Operation(summary = "Upload a payment screenshot. Returns the URL to attach to a top-up request.")
    @PostMapping(value = "/payment-slip", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public UploadResponse paymentSlip(@RequestParam("file") MultipartFile file) {
        String url = storageService.store(file, "slips");
        return new UploadResponse(url, file.getOriginalFilename(), file.getSize());
    }
}
