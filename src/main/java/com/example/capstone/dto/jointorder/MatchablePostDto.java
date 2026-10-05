package com.example.capstone.dto.jointorder;

import com.example.capstone.util.PublicLocation;

import java.time.LocalDateTime;

public record MatchablePostDto(
    Long id,
    String title,
    String storeName,
    String deliveryPlace,
    String locationName,  // 순수 POI 명칭 (매칭용)
    String userName,
    String userProfileImage,  // 작성자 프로필 이미지
    Integer currentPeople,
    Integer maxPeople,
    LocalDateTime deadline,
    boolean isRecruiting
) {
    
    public static MatchablePostDto from(com.example.capstone.domain.post.Post post) {
        return new MatchablePostDto(
            post.getId(),
            post.getTitle(),
            post.getDeliveryDetail().getRestaurantName(),
            PublicLocation.safeLabel(post.getLocationName()),
            PublicLocation.safeLabel(post.getLocationName()),
            post.getAuthor().getNickname(),
            post.getAuthor().getProfileImageUrl(),
            post.getCurrentParticipants(),
            post.getMaxParticipants(),
            post.getDeadline(),
            post.isActive()
        );
    }
}
