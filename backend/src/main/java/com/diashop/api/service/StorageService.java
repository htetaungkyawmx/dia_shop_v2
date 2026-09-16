package com.diashop.api.service;

import org.springframework.web.multipart.MultipartFile;

/** Swap the implementation to move uploads to S3/R2 without touching callers. */
public interface StorageService {

    /** @return the public URL of the stored file */
    String store(MultipartFile file, String folder);

    void delete(String url);
}
