package com.diashop.api.web;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

/** Clamps client-supplied paging so a request cannot ask for the whole table. */
public final class PageRequests {

    private static final int MAX_SIZE = 100;

    private PageRequests() {
    }

    public static PageRequest of(int page, int size) {
        return PageRequest.of(Math.max(page, 0), clamp(size));
    }

    public static PageRequest of(int page, int size, Sort sort) {
        return PageRequest.of(Math.max(page, 0), clamp(size), sort);
    }

    public static PageRequest newestFirst(int page, int size) {
        return of(page, size, Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "id")));
    }

    private static int clamp(int size) {
        if (size < 1) {
            return 20;
        }
        return Math.min(size, MAX_SIZE);
    }
}
