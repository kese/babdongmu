package com.example.capstone.domain.notification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Entity
@Table(
        name = "notification_send_history",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_notification_send_history", columnNames = {"notification_type", "reference_key", "user_id"})
        }
)
public class NotificationSendHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "notification_history_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "notification_type", length = 50, nullable = false)
    private NotificationType notificationType;

    @Column(name = "reference_key", length = 128, nullable = false)
    private String referenceKey;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "title", length = 100)
    private String title;

    @Column(name = "message", length = 500)
    private String message;

    @Column(name = "is_read", nullable = false)
    @Builder.Default
    private Boolean isRead = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        if (isRead == null) {
            isRead = false;
        }
    }

    public void markAsRead() {
        this.isRead = true;
    }

    public static NotificationSendHistory of(NotificationType type, String referenceKey, Long userId) {
        return NotificationSendHistory.builder()
                .notificationType(type)
                .referenceKey(referenceKey)
                .userId(userId)
                .build();
    }
}
