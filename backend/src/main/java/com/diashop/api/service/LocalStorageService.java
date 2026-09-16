package com.diashop.api.service;

import com.diashop.api.common.ApiException;
import com.diashop.api.config.AppProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.LocalDate;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.storage.provider", havingValue = "local", matchIfMissing = true)
public class LocalStorageService implements StorageService {

    private static final Set<String> ALLOWED_TYPES =
            Set.of("image/jpeg", "image/png", "image/webp", "image/heic");
    private static final Set<String> ALLOWED_EXTENSIONS =
            Set.of("jpg", "jpeg", "png", "webp", "heic");
    private static final long MAX_BYTES = 8L * 1024 * 1024;

    private final AppProperties props;

    @Override
    public String store(MultipartFile file, String folder) {
        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("EMPTY_FILE", "No file was uploaded.");
        }
        if (file.getSize() > MAX_BYTES) {
            throw ApiException.badRequest("FILE_TOO_LARGE", "Images must be 8MB or smaller.");
        }
        String contentType = file.getContentType() == null ? "" : file.getContentType().toLowerCase(Locale.ROOT);
        if (!ALLOWED_TYPES.contains(contentType)) {
            throw ApiException.badRequest("UNSUPPORTED_FILE_TYPE", "Only JPG, PNG, WEBP or HEIC images are allowed.");
        }
        String extension = extensionOf(file.getOriginalFilename());
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw ApiException.badRequest("UNSUPPORTED_FILE_TYPE", "Only JPG, PNG, WEBP or HEIC images are allowed.");
        }
        if (!isRealImage(file)) {
            throw ApiException.badRequest("UNSUPPORTED_FILE_TYPE", "That file is not a readable image.");
        }

        // Date folders keep any single directory small as volume grows.
        String relativeDir = sanitiseFolder(folder) + "/" + LocalDate.now();
        String fileName = UUID.randomUUID() + "." + extension;

        try {
            Path root = Paths.get(props.storage().localPath()).toAbsolutePath().normalize();
            Path target = root.resolve(relativeDir).resolve(fileName).normalize();
            if (!target.startsWith(root)) {
                throw ApiException.badRequest("INVALID_PATH", "Invalid upload target.");
            }
            Files.createDirectories(target.getParent());
            try (InputStream in = file.getInputStream()) {
                Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
            }
            return props.storage().publicBaseUrl() + "/" + relativeDir + "/" + fileName;
        } catch (IOException e) {
            log.error("Failed to store upload", e);
            throw new ApiException(org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR,
                    "UPLOAD_FAILED", "Could not save the file. Please try again.");
        }
    }

    @Override
    public void delete(String url) {
        if (url == null || !url.startsWith(props.storage().publicBaseUrl())) {
            return;
        }
        try {
            String relative = url.substring(props.storage().publicBaseUrl().length()).replaceFirst("^/", "");
            Path root = Paths.get(props.storage().localPath()).toAbsolutePath().normalize();
            Path target = root.resolve(relative).normalize();
            if (target.startsWith(root)) {
                Files.deleteIfExists(target);
            }
        } catch (IOException e) {
            log.warn("Could not delete stored file {}", url, e);
        }
    }

    private boolean isRealImage(MultipartFile file) {
        try (InputStream in = file.getInputStream()) {
            return javax.imageio.ImageIO.read(in) != null;
        } catch (IOException e) {
            return false;
        } catch (Exception e) {
            // HEIC has no ImageIO reader by default; the content type check stands in.
            return "image/heic".equalsIgnoreCase(file.getContentType());
        }
    }

    private String extensionOf(String originalName) {
        if (originalName == null) {
            return "";
        }
        int dot = originalName.lastIndexOf('.');
        return dot < 0 ? "" : originalName.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private String sanitiseFolder(String folder) {
        if (folder == null || folder.isBlank()) {
            return "misc";
        }
        String cleaned = folder.replaceAll("[^a-zA-Z0-9_-]", "");
        return cleaned.isBlank() ? "misc" : cleaned;
    }
}
