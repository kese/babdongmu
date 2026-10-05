package com.example.capstone.domain.jointorder;

import com.example.capstone.domain.User;
import com.example.capstone.domain.post.Post;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "joint_order_requests")
public class JointOrderRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "request_id")
    private Long id;

    @Version
    @Column(name = "version")
    private Long version;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requester_id", nullable = false)
    private User requester;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requester_post_id", nullable = false)
    private Post requesterPost;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private JointOrderStatus status;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "timeout_at", nullable = false)
    private LocalDateTime timeoutAt;

    @OneToMany(mappedBy = "jointOrderRequest", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<JointOrderTarget> targets = new ArrayList<>();

    @OneToMany(mappedBy = "jointOrderRequest", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<JointOrderResponse> responses = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        this.createdAt = now;
        this.timeoutAt = now.plusSeconds(300); // 5분 타임아웃
        if (this.status == null) {
            this.status = JointOrderStatus.PENDING;
        }
    }

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(timeoutAt);
    }

    public void markAsAccepted() {
        this.status = JointOrderStatus.ACCEPTED;
    }

    public void markAsRejected() {
        this.status = JointOrderStatus.REJECTED;
    }

    public void markAsTimeout() {
        this.status = JointOrderStatus.TIMEOUT;
    }

    public boolean canAccept() {
        return this.status == JointOrderStatus.PENDING && !isExpired();
    }

    public boolean isAllResponded() {
        return targets.size() == responses.size();
    }

    public boolean isAllAccepted() {
        return responses.stream().allMatch(JointOrderResponse::isAccepted);
    }
}
