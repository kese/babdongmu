package com.example.capstone.domain.post;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
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
@Table(name = "post_delivery_details")
public class DeliveryDetail {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "detail_id")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id", nullable = false, unique = true)
    @JsonIgnore
    private Post post;

    // 음식점 장소 정보
    @Column(name = "restaurant_place_id")
    private Long restaurantPlaceId;

    @Column(name = "restaurant_name", length = 255, nullable = false)
    private String restaurantName;

    @Column(name = "restaurant_address", length = 255)
    private String restaurantAddress;

    @Column(name = "restaurant_phone", length = 50)
    private String restaurantPhone;

    @Column(name = "delivery_fee", precision = 12, scale = 2, nullable = false)
    private BigDecimal deliveryFee;

    @Column(name = "order_link", length = 255)
    private String orderLink;

    @Column(name = "delivery_address", length = 255, nullable = false)
    private String deliveryAddress;

    @Column(name = "delivery_latitude", precision = 10, scale = 8)
    private BigDecimal deliveryLatitude;

    @Column(name = "delivery_longitude", precision = 11, scale = 8)
    private BigDecimal deliveryLongitude;

    @Column(name = "target_amount", precision = 12, scale = 2, nullable = false)
    private BigDecimal targetAmount;

    @Builder.Default
    @Column(name = "current_amount", precision = 12, scale = 2, nullable = false)
    private BigDecimal currentAmount = BigDecimal.ZERO;

    @Column(name = "min_order_amount", precision = 12, scale = 2)
    private BigDecimal minOrderAmount;

    @Column(name = "category", length = 100)
    private String category;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.currentAmount == null) {
            this.currentAmount = BigDecimal.ZERO;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public void update(String restaurantName,
                       String restaurantAddress,
                       String restaurantPhone,
                       BigDecimal deliveryFee,
                       String orderLink,
                       String deliveryAddress,
                       BigDecimal deliveryLatitude,
                       BigDecimal deliveryLongitude,
                       BigDecimal targetAmount,
                       BigDecimal currentAmount,
                       BigDecimal minOrderAmount,
                       String category) {
        this.restaurantName = restaurantName;
        this.restaurantAddress = restaurantAddress;
        this.restaurantPhone = restaurantPhone;
        this.deliveryFee = deliveryFee;
        this.orderLink = orderLink;
        this.deliveryAddress = deliveryAddress;
        this.deliveryLatitude = deliveryLatitude;
        this.deliveryLongitude = deliveryLongitude;
        this.targetAmount = targetAmount;
    this.currentAmount = currentAmount != null ? currentAmount : (this.currentAmount != null ? this.currentAmount : BigDecimal.ZERO);
        this.minOrderAmount = minOrderAmount;
        this.category = category;
    }

    public void updateRestaurantPlaceId(Long restaurantPlaceId) {
        this.restaurantPlaceId = restaurantPlaceId;
    }

    public void assignPost(Post post) {
        this.post = post;
    }
}
