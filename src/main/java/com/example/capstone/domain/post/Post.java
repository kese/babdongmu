package com.example.capstone.domain.post;

import com.example.capstone.domain.User;
import jakarta.persistence.CascadeType;
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
import java.util.ArrayList;
import java.util.List;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Entity
@Table(name = "posts")
public class Post {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "post_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    private User author;

    @Enumerated(EnumType.STRING)
    @Column(name = "post_type", length = 20, nullable = false)
    private PostType postType;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20, nullable = false)
    private PostStatus status;

    @Column(name = "title", length = 255, nullable = false)
    private String title;

    @Column(name = "content", columnDefinition = "TEXT", nullable = false)
    private String content;

    @Builder.Default
    @Column(name = "view_count", nullable = false)
    private Integer viewCount = 0;

    @Builder.Default
    @Column(name = "like_count", nullable = false)
    private Integer likeCount = 0;

    @Builder.Default
    @Column(name = "comment_count", nullable = false)
    private Integer commentCount = 0;

    @Column(name = "max_participants")
    private Integer maxParticipants;

    @Builder.Default
    @Column(name = "current_participants", nullable = false)
    private Integer currentParticipants = 1;

    @Column(name = "meeting_place", length = 255)
    private String meetingPlace;

    @Column(name = "meeting_time")
    private LocalDateTime meetingTime;

    // 장소 정보 (지도 마커용)
    @Column(name = "place_id")
    private Long placeId;

    @Column(name = "location_latitude", precision = 10, scale = 8)
    private BigDecimal locationLatitude;

    @Column(name = "location_longitude", precision = 11, scale = 8)
    private BigDecimal locationLongitude;

    @Column(name = "location_name", length = 200)
    private String locationName;

    @Column(name = "location_address", length = 500)
    private String locationAddress;

    @Column(name = "deadline")
    private LocalDateTime deadline;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @OneToOne(mappedBy = "post", fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
    private DeliveryDetail deliveryDetail;

    @OneToOne(mappedBy = "post", fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
    private PostMeetDetail meetDetail;

    @Builder.Default
    @OneToMany(mappedBy = "post", fetch = FetchType.LAZY)
    private List<PostParticipant> participants = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.status == null) {
            this.status = PostStatus.ACTIVE;
        }
        if (this.currentParticipants == null) {
            this.currentParticipants = 1;
        }
        if (this.viewCount == null) {
            this.viewCount = 0;
        }
        if (this.likeCount == null) {
            this.likeCount = 0;
        }
        if (this.commentCount == null) {
            this.commentCount = 0;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public boolean isActive() {
        return this.status == PostStatus.ACTIVE;
    }

    public void updateBasicInfo(String title, String content, Integer maxParticipants) {
        if (title != null && !title.isBlank()) {
            this.title = title;
        }
        if (content != null && !content.isBlank()) {
            this.content = content;
        }
        this.maxParticipants = maxParticipants;
    }

    public void updateMeetingInfo(String meetingPlace, LocalDateTime meetingTime) {
        this.meetingPlace = meetingPlace;
        this.meetingTime = meetingTime;
    }

    public void updateMaxParticipants(Integer maxParticipants) {
        this.maxParticipants = maxParticipants;
    }

    public void updateStatus(PostStatus status) {
        this.status = status;
    }

    public void updateDeadline(LocalDateTime deadline) {
        this.deadline = deadline;
    }

    public void changeStatus(PostStatus status) {
        this.status = status;
    }

    public void increaseCurrentParticipants() {
        if (this.currentParticipants == null) {
            this.currentParticipants = 0;
        }
        this.currentParticipants++;
    }

    public void setCurrentParticipants(int currentParticipants) {
        this.currentParticipants = Math.max(currentParticipants, 0);
    }

    public void updateLocationInfo(Long placeId, BigDecimal latitude, BigDecimal longitude, String locationName, String locationAddress) {
        this.placeId = placeId;
        this.locationLatitude = latitude;
        this.locationLongitude = longitude;
        this.locationName = locationName;
        this.locationAddress = locationAddress;
    }
}
