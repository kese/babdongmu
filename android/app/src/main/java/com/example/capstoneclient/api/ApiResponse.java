package com.example.capstoneclient.api;

import androidx.annotation.Nullable;

/**
 * Simple wrapper around API responses. Mirrors the Dart side structure of
 * {@code {'success': bool, 'data': ..., 'message': String}} so that the
 * Flutter and native Android layers behave consistently.
 */
public final class ApiResponse {
    private final boolean success;
    @Nullable
    private final Object data;
    @Nullable
    private final String message;

    public ApiResponse(boolean success, @Nullable Object data, @Nullable String message) {
        this.success = success;
        this.data = data;
        this.message = message;
    }

    public boolean isSuccess() {
        return success;
    }

    @Nullable
    public Object getData() {
        return data;
    }

    @Nullable
    public String getMessage() {
        return message;
    }
}
