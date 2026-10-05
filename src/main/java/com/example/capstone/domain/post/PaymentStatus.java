package com.example.capstone.domain.post;

import java.util.Locale;

public enum PaymentStatus {
    PENDING("pending"),
    PAID("paid"),
    REFUNDED("refunded"),
    CANCELLED("cancelled");

    private final String dbValue;

    PaymentStatus(String dbValue) {
        this.dbValue = dbValue;
    }

    public String getDbValue() {
        return dbValue;
    }

    public String toResponseValue() {
        return dbValue.toLowerCase(Locale.ROOT);
    }

    public static PaymentStatus fromDbValue(String value) {
        if (value == null) {
            return PENDING;
        }
        for (PaymentStatus status : values()) {
            if (status.dbValue.equalsIgnoreCase(value)) {
                return status;
            }
        }
        throw new IllegalArgumentException("Unknown payment status: " + value);
    }
}
