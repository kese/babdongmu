package com.example.capstoneclient.api;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Callable;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Java counterpart of {@code lib/services/api.dart}. Provides lightweight HTTP helpers
 * and token persistence using {@link SharedPreferences}. All network operations run on
 * a background thread via {@link ExecutorService} so callers can await the resulting
 * {@link CompletableFuture} without blocking the UI thread.
 */
public final class ApiService {
    private static final String PREFS_NAME = "capstone_prefs";
    private static final String KEY_USER_NICKNAME = "user_nickname";
    private static final String KEY_USER_NAME = "user_name";
    private static volatile String sessionToken;
    private static volatile String sessionNickname;
    private static volatile String sessionName;
    private static volatile boolean legacySessionCleared;

    public static final boolean IS_DEVELOPMENT = false;
    public static final String BASE_URL = "https://api.example.invalid";
    private static final int TIMEOUT_MILLIS = 10_000;

    private static final ExecutorService EXECUTOR = Executors.newCachedThreadPool();

    private ApiService() {
        // no-op
    }

    public static CompletableFuture<ApiResponse> post(
            @NonNull Context context,
            @NonNull String endpoint,
            @Nullable JSONObject body,
            boolean requiresAuth
    ) {
        return submitRequest(context, "POST", endpoint, body, requiresAuth);
    }

    public static CompletableFuture<ApiResponse> get(
            @NonNull Context context,
            @NonNull String endpoint,
            boolean requiresAuth
    ) {
        return submitRequest(context, "GET", endpoint, null, requiresAuth);
    }

    public static CompletableFuture<ApiResponse> delete(
            @NonNull Context context,
            @NonNull String endpoint,
            boolean requiresAuth
    ) {
        return submitRequest(context, "DELETE", endpoint, null, requiresAuth);
    }

    public static CompletableFuture<ApiResponse> put(
            @NonNull Context context,
            @NonNull String endpoint,
            @Nullable JSONObject body,
            boolean requiresAuth
    ) {
        return submitRequest(context, "PUT", endpoint, body, requiresAuth);
    }

    private static CompletableFuture<ApiResponse> submitRequest(
            @NonNull Context context,
            @NonNull String method,
            @NonNull String endpoint,
            @Nullable JSONObject body,
            boolean requiresAuth
    ) {
        Callable<ApiResponse> task = () -> executeRequest(context, method, endpoint, body, requiresAuth);
        return CompletableFuture.supplyAsync(() -> {
            try {
                return task.call();
            } catch (Exception e) {
                return new ApiResponse(false, null, "네트워크 오류: " + e.getMessage());
            }
        }, EXECUTOR);
    }

    private static ApiResponse executeRequest(
            @NonNull Context context,
            @NonNull String method,
            @NonNull String endpoint,
            @Nullable JSONObject body,
            boolean requiresAuth
    ) throws IOException {
        String urlStr = BASE_URL.endsWith("/") ? BASE_URL + endpoint : BASE_URL + "/" + endpoint;
        HttpURLConnection connection = null;
        try {
            URL url = new URL(urlStr);
            connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod(method);
            connection.setConnectTimeout(TIMEOUT_MILLIS);
            connection.setReadTimeout(TIMEOUT_MILLIS);
            connection.setRequestProperty("Content-Type", "application/json");

            if (requiresAuth) {
                String token = getToken(context);
                if (!TextUtils.isEmpty(token)) {
                    connection.setRequestProperty("Authorization", "Bearer " + token);
                }
            }

            if (body != null) {
                connection.setDoOutput(true);
                byte[] payload = body.toString().getBytes(StandardCharsets.UTF_8);
                connection.setFixedLengthStreamingMode(payload.length);
                try (OutputStream os = connection.getOutputStream()) {
                    os.write(payload);
                }
            }

            int statusCode = connection.getResponseCode();
            InputStream stream = statusCode >= 200 && statusCode < 400
                    ? connection.getInputStream()
                    : connection.getErrorStream();

            String responseBody = readStream(stream);
            return parseResponse(statusCode, responseBody);
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private static String readStream(@Nullable InputStream stream) throws IOException {
        if (stream == null) {
            return "";
        }
        StringBuilder builder = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                builder.append(line);
            }
        }
        return builder.toString();
    }

    private static ApiResponse parseResponse(int statusCode, @NonNull String responseBody) {
        if (statusCode == 200 || statusCode == 201) {
            if (responseBody.isEmpty()) {
                return new ApiResponse(true, null, null);
            }
            try {
                Object parsed = tryParseJson(responseBody);
                return new ApiResponse(true, parsed, null);
            } catch (JSONException e) {
                return new ApiResponse(true, responseBody, null);
            }
        }
        String message = "서버 오류: " + statusCode;
        try {
            Object parsed = tryParseJson(responseBody);
            if (parsed instanceof JSONObject) {
                JSONObject obj = (JSONObject) parsed;
                if (obj.has("message")) {
                    message = obj.optString("message", message);
                }
            }
        } catch (JSONException ignored) {
            // keep default message
        }
        return new ApiResponse(false, null, message);
    }

    private static Object tryParseJson(@NonNull String responseBody) throws JSONException {
        responseBody = responseBody.trim();
        if (responseBody.startsWith("{")) {
            return new JSONObject(responseBody);
        }
        // simple fallback: treat as raw string (arrays etc.)
        return responseBody;
    }

    // ----------------------------------------------------------------------
    // Token & user info helpers
    // ----------------------------------------------------------------------

    public static void saveToken(@NonNull Context context, @NonNull String token) {
        clearLegacySessionData(context);
        sessionToken = token;
    }

    @Nullable
    public static String getToken(@NonNull Context context) {
        clearLegacySessionData(context);
        return sessionToken;
    }

    public static void deleteToken(@NonNull Context context) {
        sessionToken = null;
        clearLegacySessionData(context);
    }

    public static void saveUserInfo(@NonNull Context context, @NonNull String nickname, @NonNull String name) {
        clearLegacySessionData(context);
        sessionNickname = nickname;
        sessionName = name;
    }

    @Nullable
    public static String getUserNickname(@NonNull Context context) {
        clearLegacySessionData(context);
        return sessionNickname;
    }

    @Nullable
    public static String getUserName(@NonNull Context context) {
        clearLegacySessionData(context);
        return sessionName;
    }

    public static void clearUserInfo(@NonNull Context context) {
        sessionNickname = null;
        sessionName = null;
        getPrefs(context).edit()
                .remove(KEY_USER_NICKNAME)
                .remove(KEY_USER_NAME)
                .apply();
    }

    private static void clearLegacySessionData(@NonNull Context context) {
        if (legacySessionCleared) {
            return;
        }
        getPrefs(context).edit()
                .remove("auth_token")
                .remove(KEY_USER_NICKNAME)
                .remove(KEY_USER_NAME)
                .remove("user_id")
                .apply();
        legacySessionCleared = true;
    }

    private static SharedPreferences getPrefs(@NonNull Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }
}
