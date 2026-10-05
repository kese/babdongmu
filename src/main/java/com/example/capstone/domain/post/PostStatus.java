package com.example.capstone.domain.post;

import java.util.Locale;

public enum PostStatus {
    ACTIVE,
    CLOSED,
    DONE,      // COMPLETED -> DONE (6글자)
    CANCELED,  // CANCELLED -> CANCELED (8글자)
    DELETED;

    public String toResponseValue() {
        return name().toLowerCase(Locale.ROOT);
    }
}
