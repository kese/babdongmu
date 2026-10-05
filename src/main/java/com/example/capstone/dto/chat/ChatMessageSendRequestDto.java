package com.example.capstone.dto.chat;

import jakarta.validation.constraints.NotBlank;

public record ChatMessageSendRequestDto(
        @NotBlank(message = "메시지 내용을 입력하세요.") String messageContent,
        String messageType
) {
}
