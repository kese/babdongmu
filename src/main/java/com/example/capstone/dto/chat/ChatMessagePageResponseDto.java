package com.example.capstone.dto.chat;

import java.util.List;

public record ChatMessagePageResponseDto(
        List<ChatMessageResponseDto> messages,
        boolean hasNext,
        Long nextCursor
) {
    public ChatMessagePageResponseDto {
        messages = messages == null ? List.of() : List.copyOf(messages);
    }

    public static ChatMessagePageResponseDto of(List<ChatMessageResponseDto> messages,
                                                boolean hasNext,
                                                Long nextCursor) {
        return new ChatMessagePageResponseDto(messages, hasNext, nextCursor);
    }
}
