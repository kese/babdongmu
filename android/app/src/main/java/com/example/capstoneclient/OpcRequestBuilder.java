package com.example.capstoneclient;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Builds JSON request bodies using a fluent interface.
 */
public class OpcRequestBuilder {

    private final Map<String, String> params = new LinkedHashMap<>();

    private OpcRequestBuilder() {
        // Prevent direct instantiation; use static factories below.
    }

    private static String escapeJson(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\b", "\\b")
                .replace("\f", "\\f")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }

    public static OpcRequestBuilder signup() {
        return new OpcRequestBuilder();
    }

    public static OpcRequestBuilder login() {
        return new OpcRequestBuilder();
    }

    public static OpcRequestBuilder getUser() {
        return new OpcRequestBuilder();
    }

    public static OpcRequestBuilder updateUser() {
        return new OpcRequestBuilder();
    }

    public static OpcRequestBuilder changePassword() {
        return new OpcRequestBuilder();
    }

    public static OpcRequestBuilder deleteUser() {
        return new OpcRequestBuilder();
    }

    public OpcRequestBuilder withParam(String key, String value) {
        if (key == null || key.isBlank()) {
            throw new IllegalArgumentException("Parameter key cannot be null or blank.");
        }
        params.put(key, value);
        return this;
    }

    public String build() {
        if (params.isEmpty()) {
            return "{}";
        }
        String joinedParams = params.entrySet().stream()
                .map(entry -> "\"" + entry.getKey() + "\":\"" + escapeJson(entry.getValue()) + "\"")
                .collect(Collectors.joining(","));
        return "{" + joinedParams + "}";
    }
}
