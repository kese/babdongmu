package com.example.capstone.domain.chat;

import java.util.Locale;

public enum ChatRoomType {
    DELIVERY("delivery"),
    MEET("meet"),
    DIRECT("direct"),
    GROUP("group");

    private final String dbValue;

    ChatRoomType(String dbValue) {
        this.dbValue = dbValue;
    }

    public String getDbValue() {
        return dbValue;
    }

    public static ChatRoomType fromDbValue(String value) {
        if (value == null) {
            return DELIVERY;
        }
        for (ChatRoomType type : values()) {
            if (type.dbValue.equalsIgnoreCase(value)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown chat room type: " + value);
    }

    public String toResponseValue() {
        return dbValue.toLowerCase(Locale.ROOT);
    }
}
