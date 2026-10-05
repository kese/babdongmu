package com.example.capstone.domain.chat;

import com.example.capstone.domain.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
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
@Table(name = "chat_room_participants",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_chat_room_user", columnNames = {"chat_room_id", "user_id"})
        })
public class ChatRoomParticipant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "participant_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chat_room_id", referencedColumnName = "room_id", nullable = false)
    private ChatRoom chatRoom;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "joined_at", nullable = false)
    private LocalDateTime joinedAt;

    @Column(name = "last_read_message_id")
    private Long lastReadMessageId;

    @Builder.Default
    @Column(name = "is_target", nullable = false)
    private Boolean target = Boolean.FALSE;

    @Builder.Default
    @Column(name = "has_confirmed_reception", nullable = false)
    private Boolean confirmedReception = Boolean.FALSE;

    @Builder.Default
    @Column(name = "has_reported_issue", nullable = false)
    private Boolean reportedIssue = Boolean.FALSE;

    @Builder.Default
    @Column(name = "has_accepted_delivery_guide", nullable = false)
    private Boolean hasAcceptedDeliveryGuide = Boolean.FALSE;

    @Column(name = "target_locked_at")
    private LocalDateTime targetLockedAt;

    @PrePersist
    protected void onCreate() {
        if (joinedAt == null) {
            joinedAt = LocalDateTime.now();
        }
    }

    public void markAsTarget(LocalDateTime lockedAt) {
        this.target = Boolean.TRUE;
        this.targetLockedAt = lockedAt;
        this.confirmedReception = Boolean.FALSE;
        this.reportedIssue = Boolean.FALSE;
        this.hasAcceptedDeliveryGuide = Boolean.FALSE;
    }

    public void unmarkAsTarget() {
        this.target = Boolean.FALSE;
        this.targetLockedAt = null;
        this.confirmedReception = Boolean.FALSE;
        this.reportedIssue = Boolean.FALSE;
        this.hasAcceptedDeliveryGuide = Boolean.FALSE;
    }

    public void confirmReception() {
        this.confirmedReception = Boolean.TRUE;
    }

    public void revokeReception() {
        this.confirmedReception = Boolean.FALSE;
    }

    public void reportIssue() {
        this.reportedIssue = Boolean.TRUE;
    }

    public void resetDeliveryGuideAcceptance() {
        this.hasAcceptedDeliveryGuide = Boolean.FALSE;
    }

    public void acceptDeliveryGuide() {
        this.hasAcceptedDeliveryGuide = Boolean.TRUE;
    }
}
