package com.example.capstone.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.ToString;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@ToString
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "users")
@Entity
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long id;

    @Column(length = 100, nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", length = 255, nullable = false)
    private String passwordHash;

    @Column(name = "username", length = 50, nullable = false)
    private String username;

    @Column(length = 50, nullable = false, unique = true)
    private String nickname;

    @Column(name = "phone_number", length = 20)
    private String phoneNumber;

    @Column(name = "profile_image_url", length = 255)
    private String profileImageUrl;

    @Column(name = "location_latitude", precision = 10, scale = 8)
    private BigDecimal locationLatitude;

    @Column(name = "location_longitude", precision = 11, scale = 8)
    private BigDecimal locationLongitude;

    @Column(name = "is_active")
    private Boolean isActive;

    @Column(name = "point")
    private Integer point;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @Column(name = "address", length = 255)
    private String address;

    @Column(name = "account", length = 50)
    private String account;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.isActive == null) {
            this.isActive = Boolean.TRUE;
        }
        if (this.point == null) {
            this.point = 0;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public int getPointOrDefault() {
        return point != null ? point : 0;
    }

    public void decreasePoint(int amount) {
        if (amount < 0) {
            increasePoint(-amount);
            return;
        }
        this.point = getPointOrDefault() - amount;
    }

    public void increasePoint(int amount) {
        if (amount < 0) {
            decreasePoint(-amount);
            return;
        }
        this.point = getPointOrDefault() + amount;
    }

    // 프로필 업데이트 메서드들
    public void updateUsername(String username) {
        if (username != null && !username.isBlank()) {
            this.username = username;
        }
    }

    public void updateNickname(String nickname) {
        if (nickname != null && !nickname.isBlank()) {
            this.nickname = nickname;
        }
    }

    public void updatePhoneNumber(String phoneNumber) {
        this.phoneNumber = phoneNumber;
    }

    public void updateEmail(String email) {
        if (email != null && !email.isBlank()) {
            this.email = email;
        }
    }

    public void updateAddress(String address) {
        this.address = address;
    }

    public void updateAccount(String account) {
        this.account = account;
    }

    public void updateProfileImageUrl(String profileImageUrl) {
        this.profileImageUrl = profileImageUrl;
    }

    public void updatePassword(String passwordHash) {
        if (passwordHash != null && !passwordHash.isBlank()) {
            this.passwordHash = passwordHash;
        }
    }

    public void softDelete() {
        this.deletedAt = LocalDateTime.now();
        this.isActive = false;
    }
}


