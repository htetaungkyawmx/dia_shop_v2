package com.diashop.api.web;

import com.diashop.api.common.ApiException;
import com.diashop.api.domain.User;
import com.diashop.api.repository.UserRepository;
import com.diashop.api.security.AuthUser;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Loads the full User entity for endpoints whose service needs one. */
@Component
@RequiredArgsConstructor
public class CurrentUserService {

    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public User require(AuthUser principal) {
        if (principal == null) {
            throw ApiException.unauthorized("Please sign in to continue.");
        }
        return userRepository.findById(principal.id())
                .orElseThrow(() -> ApiException.unauthorized("Your account is no longer available."));
    }
}
