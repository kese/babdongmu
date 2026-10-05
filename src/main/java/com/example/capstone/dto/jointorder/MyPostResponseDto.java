package com.example.capstone.dto.jointorder;

import com.example.capstone.domain.post.DeliveryDetail;

import java.time.LocalDateTime;

public record MyPostResponseDto(
    Long id,
    String title,
    String storeName,
    String deliveryPlace,
    String locationName,  // 순수 POI 명칭 (매칭용)
    Integer deliveryFee,
    Integer currentPeople,
    Integer maxPeople,
    LocalDateTime deadline,
    boolean isRecruiting,
    DeliveryDetail deliveryDetail
) {
    
    public static MyPostResponseDto from(com.example.capstone.domain.post.Post post) {
        return new MyPostResponseDto(
            post.getId(),
            post.getTitle(),
            post.getDeliveryDetail().getRestaurantName(),
            post.getDeliveryDetail().getDeliveryAddress(),
            post.getLocationName(),  // ★★★ 순수 POI 명칭 추가 ★★★
            post.getDeliveryDetail().getDeliveryFee().intValue(),
            post.getCurrentParticipants(),
            post.getMaxParticipants(),
            post.getDeadline(),
            post.isActive(),
            post.getDeliveryDetail()
        );
    }
}
