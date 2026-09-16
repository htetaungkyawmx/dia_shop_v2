package com.diashop.api.repository;

import com.diashop.api.domain.PaymentMethod;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PaymentMethodRepository extends JpaRepository<PaymentMethod, Long> {

    List<PaymentMethod> findByActiveTrueOrderBySortOrderAscIdAsc();

    List<PaymentMethod> findAllByOrderBySortOrderAscIdAsc();

    Optional<PaymentMethod> findByCode(String code);

    boolean existsByCode(String code);
}
