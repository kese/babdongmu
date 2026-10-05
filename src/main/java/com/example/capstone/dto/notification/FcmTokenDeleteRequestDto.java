package com.example.capstone.dto.notification;

import jakarta.validation.constraints.NotBlank;

public record FcmTokenDeleteRequestDto(@NotBlank(message = "FCM 토큰은 필수입니다.") String token) {
}
