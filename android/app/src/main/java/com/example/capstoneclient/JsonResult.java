package com.example.capstoneclient;

/**
 * Simple wrapper for JSON HTTP responses.
 */
public class JsonResult {
    private final int statusCode;
    private final String body;

    public JsonResult(int statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public int getStatusCode() {
        return statusCode;
    }

    public String getBody() {
        return body;
    }

    public boolean isCreated() {
        return statusCode == 201;
    }

    public boolean isBadRequest() {
        return statusCode == 400;
    }

    public boolean isConflict() {
        return statusCode == 409;
    }

    public boolean isServerError() {
        return statusCode >= 500 && statusCode < 600;
    }
}
