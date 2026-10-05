package com.example.capstone.dto;

public record ApiEnvelope<T>(boolean success, String message, T data) {

    private static final String DEFAULT_SUCCESS_MESSAGE = "OK";

    public static <T> ApiEnvelope<T> ok(T data) {
        return new ApiEnvelope<>(true, DEFAULT_SUCCESS_MESSAGE, data);
    }

    public static <T> ApiEnvelope<T> ok(String message, T data) {
        return new ApiEnvelope<>(true, message, data);
    }

    public static <T> ApiEnvelope<T> fail(String message) {
        return new ApiEnvelope<>(false, message, null);
    }
}
