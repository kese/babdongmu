package com.example.capstone.domain.chat;

public enum MessageType {
    TEXT("text"),
    IMAGE("image"),
    SYSTEM("system"),
    FILE("file"),
    NOTICE("notice"),
    RECEIPT("receipt");

    private final String dbValue;

    MessageType(String dbValue) {
        this.dbValue = dbValue;
    }

    public String getDbValue() {
        return dbValue;
    }

    public static MessageType fromDbValue(String value) {
        if (value == null) {
            return TEXT;
        }
        for (MessageType type : values()) {
            if (type.dbValue.equalsIgnoreCase(value)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown message type: " + value);
    }
}
