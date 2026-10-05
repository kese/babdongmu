package com.example.capstone.domain;

import jakarta.persistence.*;
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
@Table(name = "auth_events")
@Entity
public class AuthEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "event_id")
    private Long id;

    @Convert(converter = AuthEventTypeConverter.class)
    @Column(name = "event_type", nullable = false, length = 32)
    private AuthEventType type;

    @Column(name = "email", length = 100)
    private String email;

    @Column(name = "user_id")
    private Long userId; // nullable when unknown

    @Column(name = "success", nullable = false)
    private boolean success;

    @Column(name = "reason", columnDefinition = "TEXT")
    private String reason; // optional failure reason

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}


