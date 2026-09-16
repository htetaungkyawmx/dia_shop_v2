package com.diashop.api.service;

import com.diashop.api.domain.AuditLog;
import com.diashop.api.domain.User;
import com.diashop.api.repository.AuditLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditLogRepository repository;

    /**
     * Written in its own transaction: an audit row must survive even when the
     * surrounding business transaction later rolls back for an unrelated reason.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(User actor, String action, String entityType, Object entityId, String detail) {
        AuditLog log = new AuditLog();
        log.setActor(actor);
        log.setAction(action);
        log.setEntityType(entityType);
        log.setEntityId(entityId == null ? null : String.valueOf(entityId));
        log.setDetail(detail);
        repository.save(log);
    }
}
