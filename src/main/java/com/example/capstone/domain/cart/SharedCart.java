package com.example.capstone.domain.cart;

import com.example.capstone.domain.User;
import com.example.capstone.domain.chat.ChatRoom;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
import jakarta.persistence.UniqueConstraint;
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
@Table(name = "shared_cart", uniqueConstraints = {
        @UniqueConstraint(name = "uk_shared_cart_active", columnNames = "active_room_id")
})
public class SharedCart {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "room_id", nullable = false)
    private ChatRoom chatRoom;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "host_id", nullable = false)
    private User host;

    @Builder.Default
    @Column(name = "is_active", nullable = false)
    private Boolean active = Boolean.TRUE;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Column(name = "active_room_id")
    private Long activeRoomId;

    @Builder.Default
    @OneToMany(mappedBy = "cart", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<SharedCartItem> items = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.items == null) {
            this.items = new ArrayList<>();
        }
        if (this.active == null) {
            this.active = Boolean.TRUE;
        }
        syncActiveRoomId();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
        syncActiveRoomId();
    }

    public static SharedCart initialize(ChatRoom chatRoom, User host) {
        SharedCart cart = SharedCart.builder()
                .chatRoom(chatRoom)
                .host(host)
                .build();
        cart.markActive();
        return cart;
    }

    public boolean isActive() {
        return Boolean.TRUE.equals(this.active);
    }

    public void markActive() {
        this.active = Boolean.TRUE;
        this.completedAt = null;
        this.activeRoomId = chatRoom != null ? chatRoom.getId() : null;
    }

    public void markCompleted(LocalDateTime when) {
        this.active = Boolean.FALSE;
        this.completedAt = when != null ? when : LocalDateTime.now();
        this.activeRoomId = null;
    }

    private void syncActiveRoomId() {
        if (Boolean.TRUE.equals(this.active)) {
            this.activeRoomId = chatRoom != null ? chatRoom.getId() : null;
        }
    }
}
