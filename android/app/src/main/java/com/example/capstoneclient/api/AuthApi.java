package com.example.capstoneclient.api;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

/**
 * Java version of the Dart {@code AuthApi}. Provides dev-mode mocks as well as
 * real HTTP calls using {@link ApiService}. All methods return
 * {@link CompletableFuture} so callers can chain them similarly to Dart Futures.
 */
public final class AuthApi {
    private static final String TAG = "AuthApi";

    private static final List<JSONObject> TEMP_USERS = Collections.synchronizedList(new ArrayList<>());

    private AuthApi() {
        // no-op
    }

    public static CompletableFuture<ApiResponse> signUp(
            @NonNull Context context,
            @NonNull String email,
            @NonNull String password,
            @NonNull String name,
            @NonNull String nickname,
            @Nullable String address,
            @Nullable String phone,
            @Nullable String account
    ) {
        if (ApiService.IS_DEVELOPMENT) {
            return CompletableFuture.supplyAsync(() -> {
                synchronized (TEMP_USERS) {
                    for (JSONObject user : TEMP_USERS) {
                        if (email.equals(user.optString("email"))) {
                            return new ApiResponse(false, null, "이미 가입된 이메일입니다");
                        }
                    }
                    JSONObject newUser = new JSONObject();
                    try {
                        newUser.put("email", email)
                                .put("password", password)
                                .put("name", name)
                                .put("nickname", nickname)
                                .put("address", address != null ? address : "")
                                .put("phone", phone != null ? phone : "")
                                .put("account", account != null ? account : "");
                    } catch (JSONException e) {
                        return new ApiResponse(false, null, "데이터 구성 오류: " + e.getMessage());
                    }
                    TEMP_USERS.add(newUser);
                    Log.d(TAG, "Mock signup completed");
                    return new ApiResponse(true, null, "회원가입 성공");
                }
            });
        }

        JSONObject payload = new JSONObject();
        try {
            payload.put("email", email)
                    .put("password", password)
                    .put("name", name)
                    .put("nickname", nickname)
                    .put("address", address)
                    .put("phone", phone)
                    .put("account", account);
        } catch (JSONException e) {
            return CompletableFuture.completedFuture(new ApiResponse(false, null, "데이터 구성 오류: " + e.getMessage()));
        }

        return ApiService.post(context, "api/auth/signup", payload, false);
    }

    public static CompletableFuture<ApiResponse> login(
            @NonNull Context context,
            @NonNull String email,
            @NonNull String password
    ) {
        if (ApiService.IS_DEVELOPMENT) {
            return CompletableFuture.supplyAsync(() -> handleDevLogin(context, email, password));
        }

        JSONObject payload = new JSONObject();
        try {
            payload.put("email", email)
                    .put("password", password);
        } catch (JSONException e) {
            return CompletableFuture.completedFuture(new ApiResponse(false, null, "데이터 구성 오류: " + e.getMessage()));
        }

        return ApiService.post(context, "api/auth/login", payload, false)
                .thenApply(response -> {
                    if (response.isSuccess()) {
                        handleRealLoginPersistence(context, response.getData());
                    } else {
                        ApiService.deleteToken(context);
                        ApiService.clearUserInfo(context);
                    }
                    return response;
                });
    }

    private static ApiResponse handleDevLogin(@NonNull Context context, @NonNull String email, @NonNull String password) {
        try {
            Thread.sleep(1_000); // match Dart delay
        } catch (InterruptedException ignored) {
        }

        synchronized (TEMP_USERS) {
            for (JSONObject user : TEMP_USERS) {
                if (email.equals(user.optString("email")) && password.equals(user.optString("password"))) {
                    String mockToken = "mock-" + UUID.randomUUID();
                    ApiService.saveToken(context, mockToken);
                    ApiService.saveUserInfo(context,
                            user.optString("nickname", "사용자"),
                            user.optString("name", "알 수 없음"));
                    JSONObject data = new JSONObject();
                    JSONObject userPayload = new JSONObject();
                    try {
                        data.put("token", mockToken);
                        userPayload.put("email", email)
                                .put("nickname", user.optString("nickname"))
                                .put("name", user.optString("name"));
                        data.put("user", userPayload);
                    } catch (JSONException e) {
                        return new ApiResponse(false, null, "데이터 구성 오류: " + e.getMessage());
                    }
                    Log.d(TAG, "Mock login completed");
                    return new ApiResponse(true, data, "로그인 성공");
                }
            }
        }

        Log.d(TAG, "Mock login failed");
        return new ApiResponse(false, null, "이메일 또는 비밀번호가 일치하지 않습니다");
    }

    private static void handleRealLoginPersistence(@NonNull Context context, @Nullable Object data) {
        if (data == null) {
            return;
        }
        if (data instanceof String) {
            ApiService.saveToken(context, data.toString());
            ApiService.saveUserInfo(context, "사용자", "알 수 없음");
            return;
        }

        if (!(data instanceof JSONObject)) {
            ApiService.saveUserInfo(context, "사용자", "알 수 없음");
            return;
        }

        JSONObject obj = (JSONObject) data;
        String token = obj.optString("accessToken", obj.optString("token", obj.optString("jwt", null)));
        if (token != null) {
            ApiService.saveToken(context, token);
        }

        String nickname = null;
        String name = null;

        if (obj.has("user")) {
            JSONObject user = obj.optJSONObject("user");
            if (user != null) {
                nickname = safeString(user, "nickname");
                name = safeString(user, "name");
            }
        }

        if (nickname == null) {
            nickname = safeString(obj, "nickname");
        }
        if (name == null) {
            name = safeString(obj, "name");
        }

        ApiService.saveUserInfo(context, nickname != null ? nickname : "사용자", name != null ? name : "알 수 없음");
    }

    @Nullable
    private static String safeString(@NonNull JSONObject obj, @NonNull String key) {
        if (!obj.has(key)) {
            return null;
        }
        Object value = obj.opt(key);
        return value != null ? value.toString() : null;
    }

    /** Utility method for debugging the in-memory user store. */
    public static JSONArray dumpTempUsers() {
        synchronized (TEMP_USERS) {
            return new JSONArray(TEMP_USERS);
        }
    }
}
