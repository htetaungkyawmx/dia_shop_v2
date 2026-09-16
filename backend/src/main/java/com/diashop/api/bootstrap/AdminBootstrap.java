package com.diashop.api.bootstrap;

import com.diashop.api.config.AppProperties;
import com.diashop.api.domain.Role;
import com.diashop.api.domain.User;
import com.diashop.api.domain.UserStatus;
import com.diashop.api.repository.UserRepository;
import com.diashop.api.service.WalletService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;

/**
 * Creates the first super admin so a fresh install can be signed into.
 * Runs only when no admin exists; it never resets an existing password.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AdminBootstrap implements ApplicationRunner {

    private static final String DEFAULT_PASSWORD = "Admin@12345";

    private final UserRepository userRepository;
    private final WalletService walletService;
    private final PasswordEncoder passwordEncoder;
    private final AppProperties props;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (userRepository.existsByRoleIn(List.of(Role.ADMIN, Role.SUPER_ADMIN))) {
            return;
        }

        String email = props.admin().email().trim().toLowerCase(Locale.ROOT);
        String password = props.admin().password();

        User admin = userRepository.findByEmailIgnoreCase(email).orElseGet(User::new);
        admin.setEmail(email);
        admin.setDisplayName(props.admin().displayName());
        admin.setPasswordHash(passwordEncoder.encode(password));
        admin.setRole(Role.SUPER_ADMIN);
        admin.setStatus(UserStatus.ACTIVE);
        admin.setEmailVerified(true);
        User saved = userRepository.save(admin);
        walletService.getOrCreate(saved);

        log.info("Created the first admin account: {}", email);
        if (DEFAULT_PASSWORD.equals(password)) {
            log.warn("""
                    ====================================================================
                     The admin account uses the built-in default password.
                     Sign in and change it now, or set ADMIN_PASSWORD before first boot.
                    ====================================================================""");
        }
    }
}
