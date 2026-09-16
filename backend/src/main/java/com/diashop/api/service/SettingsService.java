package com.diashop.api.service;

import com.diashop.api.domain.AppSetting;
import com.diashop.api.repository.AppSettingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Thin typed accessor over the app_settings key/value table. */
@Service
@RequiredArgsConstructor
public class SettingsService {

    public static final String MAINTENANCE = "app.maintenance";
    public static final String MAINTENANCE_MESSAGE = "app.maintenance_message";
    public static final String APP_NAME = "app.name";
    public static final String TOPUP_MIN = "topup.min_amount";
    public static final String TOPUP_MAX = "topup.max_amount";
    public static final String AUTO_DELIVER_CODES = "order.auto_complete_code_delivery";

    private final AppSettingRepository repository;

    @Transactional(readOnly = true)
    public String get(String key, String fallback) {
        return repository.findById(key).map(AppSetting::getValue).orElse(fallback);
    }

    @Transactional(readOnly = true)
    public boolean getBoolean(String key, boolean fallback) {
        return Boolean.parseBoolean(get(key, String.valueOf(fallback)));
    }

    @Transactional(readOnly = true)
    public long getLong(String key, long fallback) {
        try {
            return Long.parseLong(get(key, String.valueOf(fallback)));
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    @Transactional(readOnly = true)
    public Map<String, String> all() {
        Map<String, String> map = new LinkedHashMap<>();
        repository.findAll().forEach(s -> map.put(s.getKey(), s.getValue()));
        return map;
    }

    @Transactional(readOnly = true)
    public Map<String, String> withPrefix(String prefix) {
        Map<String, String> map = new LinkedHashMap<>();
        repository.findAll().stream()
                .filter(s -> s.getKey().startsWith(prefix))
                .forEach(s -> map.put(s.getKey().substring(prefix.length()), s.getValue()));
        return map;
    }

    @Transactional(readOnly = true)
    public List<AppSetting> allEntities() {
        return repository.findAll();
    }

    @Transactional
    public void put(String key, String value) {
        AppSetting setting = repository.findById(key).orElseGet(() -> {
            AppSetting fresh = new AppSetting();
            fresh.setKey(key);
            return fresh;
        });
        setting.setValue(value);
        setting.setUpdatedAt(Instant.now());
        repository.save(setting);
    }
}
