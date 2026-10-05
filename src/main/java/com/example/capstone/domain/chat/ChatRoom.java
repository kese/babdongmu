package com.example.capstone.domain.chat;

import com.example.capstone.domain.post.Post;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Entity
@Table(name = "chat_rooms")
public class ChatRoom {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "room_id")
    private Long id;

    @Column(name = "room_name", length = 255)
    private String roomName;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @Column(name = "room_type", length = 20, nullable = false)
    private ChatRoomType roomType;

    @Builder.Default
    @Enumerated(EnumType.STRING)
    @Column(name = "room_status", length = 20, nullable = false)
    private ChatRoomStatus roomStatus = ChatRoomStatus.BEFORE_ORDER;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Column(name = "max_capacity")
    private Integer maxCapacity;

    @Builder.Default
    @Column(name = "escrow_total_point", nullable = false)
    private Integer escrowTotalPoint = 0;

    @Builder.Default
    @Column(name = "escrow_target_point", nullable = false)
    private Integer escrowTargetPoint = 0;

    @Column(name = "escrow_locked_at")
    private LocalDateTime escrowLockedAt;

    @Builder.Default
    @Column(name = "is_active", nullable = false)
    private Boolean active = Boolean.TRUE;

    @Builder.Default
    @OneToMany(mappedBy = "chatRoom", fetch = FetchType.LAZY)
    private List<ChatRoomParticipant> participants = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.roomType == null) {
            this.roomType = ChatRoomType.DELIVERY;
        }
        if (this.roomStatus == null) {
            this.roomStatus = ChatRoomStatus.BEFORE_ORDER;
        }
        if (this.active == null) {
            this.active = Boolean.TRUE;
        }
        if (this.escrowTotalPoint == null) {
            this.escrowTotalPoint = 0;
        }
        if (this.escrowTargetPoint == null) {
            this.escrowTargetPoint = 0;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public void updateStatus(ChatRoomStatus status) {
        if (status != null) {
            this.roomStatus = status;
        }
    }

    public void updateMaxCapacity(Integer maxCapacity) {
        this.maxCapacity = maxCapacity;
    }

    public void updateRoomName(String roomName) {
        this.roomName = roomName;
    }

    public void updateRoomType(ChatRoomType roomType) {
        if (roomType != null) {
            this.roomType = roomType;
        }
    }

    public void deactivate() {
        this.active = Boolean.FALSE;
        if (this.roomStatus == null || this.roomStatus == ChatRoomStatus.BEFORE_ORDER) {
            this.roomStatus = ChatRoomStatus.COMPLETED;
        }
    }

    public void lockEscrow(Integer targetPoint, LocalDateTime lockedAt) {
        this.escrowTargetPoint = targetPoint != null ? targetPoint : 0;
        this.escrowLockedAt = lockedAt;
    }

    public void updateEscrowTotal(Integer totalPoint) {
        this.escrowTotalPoint = totalPoint != null ? totalPoint : 0;
    }

    public void clearEscrow() {
        this.escrowTotalPoint = 0;
        this.escrowTargetPoint = 0;
        this.escrowLockedAt = null;
    }
}
