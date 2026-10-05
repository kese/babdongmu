package com.example.capstone.dto.notification;

import jakarta.validation.constraints.NotBlank;

public record FcmTokenRegisterRequestDto(
        @NotBlank(message = "FCM 토큰은 필수입니다.") String token,
        String deviceId
) {
}
