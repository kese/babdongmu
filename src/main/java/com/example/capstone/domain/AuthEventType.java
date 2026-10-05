package com.example.capstone.domain;

public enum AuthEventType {
    LOGIN("login"),
    LOGOUT("logout"),
    TOKEN_REFRESH("token_refresh"),
    PASSWORD_CHANGE("password_change"),
    FAILED_LOGIN("failed_login");

    private final String dbValue;

    AuthEventType(String dbValue) {
        this.dbValue = dbValue;
    }

    public String getDbValue() {
        return dbValue;
    }

    public static AuthEventType fromDbValue(String value) {
        if (value == null) {
            return null;
        }
        for (AuthEventType type : values()) {
            if (type.dbValue.equalsIgnoreCase(value)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown auth event type: " + value);
    }
}


