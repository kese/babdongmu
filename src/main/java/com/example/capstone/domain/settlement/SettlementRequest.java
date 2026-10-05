package com.example.capstone.domain.settlement;

import com.example.capstone.domain.User;
import com.example.capstone.domain.cart.SharedCart;
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

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Entity
@Table(name = "settlement_requests",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_settlement_request_pending", columnNames = {"shared_cart_id", "requester_id", "status"})
        })
public class SettlementRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "settlement_request_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "shared_cart_id", nullable = false)
    private SharedCart cart;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requester_id", nullable = false)
    private User requester;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "processed_by_id")
    private User processedBy;

    @Column(name = "amount", nullable = false)
    private Integer amount;

    @Column(name = "delivery_fee_share")
    private Integer deliveryFeeShare;

    @Column(name = "memo", length = 255)
    private String memo;

    @Column(name = "decision_memo", length = 255)
    private String decisionMemo;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 32, nullable = false)
    private SettlementRequestStatus status;

    @Column(name = "requested_at", nullable = false, updatable = false)
    private LocalDateTime requestedAt;

    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        this.requestedAt = now;
        this.updatedAt = now;
        if (this.status == null) {
            this.status = SettlementRequestStatus.PENDING;
        }
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public void assignCart(SharedCart cart) {
        this.cart = cart;
    }

    public void assignRequester(User requester) {
        this.requester = requester;
    }

    public void approve(User processor, String decisionMemo) {
        this.status = SettlementRequestStatus.APPROVED;
        this.processedBy = processor;
        this.processedAt = LocalDateTime.now();
        this.decisionMemo = decisionMemo;
    }

    public void reject(User processor, String decisionMemo) {
        this.status = SettlementRequestStatus.REJECTED;
        this.processedBy = processor;
        this.processedAt = LocalDateTime.now();
        this.decisionMemo = decisionMemo;
    }
}
