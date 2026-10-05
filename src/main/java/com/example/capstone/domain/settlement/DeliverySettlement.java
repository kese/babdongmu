package com.example.capstone.domain.settlement;

import com.example.capstone.domain.User;
import com.example.capstone.domain.cart.SharedCart;
import com.example.capstone.domain.post.Post;
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
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Entity
@Table(name = "delivery_settlements")
public class DeliverySettlement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "settlement_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shared_cart_id", nullable = false)
    private SharedCart cart;

    @Column(name = "participant_count", nullable = false)
    private Integer participantCount;

    @Column(name = "original_delivery_fee", precision = 14, scale = 2, nullable = false)
    private BigDecimal originalDeliveryFee;

    @Column(name = "paid_delivery_fee", precision = 14, scale = 2, nullable = false)
    private BigDecimal paidDeliveryFee;

    @Column(name = "saved_delivery_fee", precision = 14, scale = 2, nullable = false)
    private BigDecimal savedDeliveryFee;

    @Column(name = "points_charged", nullable = false)
    private Integer pointsCharged;

    @Column(name = "settled_at", nullable = false)
    private LocalDateTime settledAt;

    @PrePersist
    protected void onPersist() {
        if (settledAt == null) {
            settledAt = LocalDateTime.now();
        }
    }

    public static DeliverySettlement of(User user,
                                        Post post,
                                        SharedCart cart,
                                        int participantCount,
                                        BigDecimal originalDeliveryFee,
                                        BigDecimal paidDeliveryFee,
                                        BigDecimal savedDeliveryFee,
                                        int pointsCharged,
                                        LocalDateTime settledAt) {
        return DeliverySettlement.builder()
                .user(user)
                .post(post)
                .cart(cart)
                .participantCount(participantCount)
                .originalDeliveryFee(originalDeliveryFee)
                .paidDeliveryFee(paidDeliveryFee)
                .savedDeliveryFee(savedDeliveryFee)
                .pointsCharged(pointsCharged)
                .settledAt(settledAt)
                .build();
    }
}
