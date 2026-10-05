package com.example.capstone.dto.notification;

import com.example.capstone.domain.notification.NotificationSendHistory;

import java.time.LocalDateTime;

public record NotificationResponseDto(
        Long id,
        String type,
        String referenceKey,
        String title,
        String message,
        Boolean isRead,
        LocalDateTime createdAt
) {
    public static NotificationResponseDto from(NotificationSendHistory history) {
        return new NotificationResponseDto(
                history.getId(),
                history.getNotificationType().name(),
                history.getReferenceKey(),
                history.getTitle(),
                history.getMessage(),
                history.getIsRead() != null ? history.getIsRead() : false,
                history.getCreatedAt()
        );
    }
}
