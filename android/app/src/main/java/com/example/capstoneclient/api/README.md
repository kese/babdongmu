# Native Auth API Helpers

This package contains a lightweight Java translation of the Flutter `AuthApi`
and `ApiService` logic so native Android components can call the same
endpoints.

## Provided classes

- `ApiResponse` – mirrors the Dart response shape (`success`, `data`, `message`).
- `ApiService` – wraps HTTP calls (`GET`, `POST`, `PUT`, `DELETE`) and stores
  session tokens and user info in memory for the current app process.
- `AuthApi` – exposes `signUp` and `login` with the local mock behavior used by
  the Flutter implementation.

## Usage

```java
// Example inside an Activity or ViewModel (call off the main thread)
AuthApi.login(context, email, password)
    .thenAccept(response -> {
      if (response.isSuccess()) {
        // Session data is available in memory while this process is running.
      } else {
        // Handle error UI on the main thread as appropriate
      }
    });
```

> ⚠️ Network calls run on a background `ExecutorService`, but UI updates must
> still be posted back to the main thread.

The base URL is a reserved `.invalid` address. This legacy helper is not
connected to an active server. Session data is cleared when the process exits,
so the user must sign in again after restarting the app.
