package com.example.capstone.domain.post;

import java.util.Locale;

public enum PostType {
    DELIVERY,
    MEET;

    public String toResponseValue() {
        return name().toLowerCase(Locale.ROOT);
    }
}
