package com.example.capstone.domain.place;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Entity
@Table(name = "places")
public class Place {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "place_id")
    private Long id;

    @Column(name = "external_id", length = 100, unique = true)
    private String externalId; // 카카오맵 API의 place ID

    @Column(name = "place_name", length = 200, nullable = false)
    private String placeName;

    @Column(name = "category", length = 100)
    private String category;

    @Column(name = "address", length = 500, nullable = false)
    private String address;

    @Column(name = "road_address", length = 500)
    private String roadAddress;

    @Column(name = "latitude", precision = 10, scale = 8, nullable = false)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 11, scale = 8, nullable = false)
    private BigDecimal longitude;

    @Column(name = "phone", length = 20)
    private String phone;

    @Column(name = "place_url", length = 500)
    private String placeUrl;

    @Builder.Default
    @Column(name = "search_count", nullable = false)
    private Integer searchCount = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.searchCount == null) {
            this.searchCount = 0;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public void incrementSearchCount() {
        this.searchCount++;
    }

    public void updateInfo(String placeName, String category, String address, String roadAddress, String phone, String placeUrl) {
        if (placeName != null) this.placeName = placeName;
        if (category != null) this.category = category;
        if (address != null) this.address = address;
        if (roadAddress != null) this.roadAddress = roadAddress;
        if (phone != null) this.phone = phone;
        if (placeUrl != null) this.placeUrl = placeUrl;
    }
}

