package com.example.capstone.domain.chat;

import com.example.capstone.domain.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.Lob;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
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
@Table(name = "chat_messages")
public class ChatMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "message_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "room_id", nullable = false)
    private ChatRoom chatRoom;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User sender;

    @Column(name = "message_content", columnDefinition = "TEXT", nullable = false)
    private String messageContent;

    @Builder.Default
    @Column(name = "message_type", length = 20, nullable = false)
    private MessageType messageType = MessageType.TEXT;

    @Column(name = "sent_at", nullable = false, updatable = false)
    private LocalDateTime sentAt;

    @Builder.Default
    @Column(name = "is_read", nullable = false)
    private Boolean read = Boolean.FALSE;

    @Lob
    @Column(name = "cart_summary_json")
    private String cartSummaryJson;

    @PrePersist
    protected void onCreate() {
        if (sentAt == null) {
            sentAt = LocalDateTime.now();
        }
        if (messageType == null) {
            messageType = MessageType.TEXT;
        }
        if (read == null) {
            read = Boolean.FALSE;
        }
    }

    public void attachCartSummary(String summaryJson) {
        this.cartSummaryJson = summaryJson;
    }

    public void updateChatRoom(ChatRoom newChatRoom) {
        this.chatRoom = newChatRoom;
    }
}
