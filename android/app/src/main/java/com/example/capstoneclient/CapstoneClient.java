package com.example.capstoneclient;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

/**
 * Lightweight HTTP client that mirrors the previous desktop client logic
 * using OkHttp so it can run inside the Android module.
 */
public class CapstoneClient {
    private static final String BASE_URL = "https://api.example.invalid";
    private static final MediaType JSON = MediaType.get("application/json; charset=utf-8");

    private final OkHttpClient httpClient;

    public CapstoneClient() {
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(5, TimeUnit.SECONDS)
                .readTimeout(10, TimeUnit.SECONDS)
                .build();
    }

    private JsonResult execute(Request request) throws IOException {
        try (Response response = httpClient.newCall(request).execute()) {
            String responseBody = response.body() != null ? response.body().string() : "";
            return new JsonResult(response.code(), responseBody);
        }
    }

    public JsonResult signup(String jsonBody) throws IOException {
        Request request = new Request.Builder()
                .url(BASE_URL + "/api/auth/signup")
                .post(RequestBody.create(jsonBody, JSON))
                .build();
        return execute(request);
    }

    public JsonResult login(String jsonBody) throws IOException {
        Request request = new Request.Builder()
                .url(BASE_URL + "/api/auth/login")
                .post(RequestBody.create(jsonBody, JSON))
                .build();
        return execute(request);
    }

    public JsonResult getUser(String userId) throws IOException {
        Request request = new Request.Builder()
                .url(BASE_URL + "/api/users/" + userId)
                .get()
                .build();
        return execute(request);
    }

    public JsonResult updateUser(String userId, String jsonBody) throws IOException {
        Request request = new Request.Builder()
                .url(BASE_URL + "/api/users/" + userId)
                .put(RequestBody.create(jsonBody, JSON))
                .build();
        return execute(request);
    }

    public JsonResult changePassword(String userId, String jsonBody) throws IOException {
        Request request = new Request.Builder()
                .url(BASE_URL + "/api/users/" + userId + "/password")
                .put(RequestBody.create(jsonBody, JSON))
                .build();
        return execute(request);
    }

    public JsonResult deleteUser(String userId) throws IOException {
        Request request = new Request.Builder()
                .url(BASE_URL + "/api/users/" + userId)
                .delete()
                .build();
        return execute(request);
    }
}
