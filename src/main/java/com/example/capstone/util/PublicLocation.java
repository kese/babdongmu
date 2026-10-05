package com.example.capstone.util;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.regex.Pattern;

/** Filters private address details from delivery post labels and coordinates. */
public final class PublicLocation {

    public static final String GENERIC_LABEL = "대략적 위치";

    private static final Pattern PRIVATE_ADDRESS = Pattern.compile(
            "(?i).*(\\d{1,4}\\s*(동|호|층|호실)|(?:대로|로|길)\\s*\\d+|아파트|오피스텔|빌라|원룸|주택|\\d{2,4}-\\d{3,4}-\\d{4}).*"
    );

    private PublicLocation() {}

    public static String safeLabel(String candidate) {
        if (candidate == null || candidate.isBlank()) {
            return GENERIC_LABEL;
        }
        String normalized = candidate.trim().replaceAll("\\s+", " ");
        if (normalized.length() > 80 || PRIVATE_ADDRESS.matcher(normalized).matches()) {
            return GENERIC_LABEL;
        }
        return normalized;
    }

    public static BigDecimal approximateCoordinate(BigDecimal coordinate) {
        return coordinate == null ? null : coordinate.setScale(3, RoundingMode.HALF_UP);
    }
}
