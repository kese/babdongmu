package com.example.capstone.domain.post;

public enum ParticipantRole {
    CREATOR,
    MEMBER;

    public String toDatabaseValue() {
        return name().toLowerCase();
    }

    public static ParticipantRole fromDatabaseValue(String value) {
        if (value == null) {
            return MEMBER;
        }
        return ParticipantRole.valueOf(value.toUpperCase());
    }
}
