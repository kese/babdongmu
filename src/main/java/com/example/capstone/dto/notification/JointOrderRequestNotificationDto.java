package com.example.capstone.dto.notification;

public record JointOrderRequestNotificationDto(
        Long requestId,
        Long postId,
        Long requesterId,
        String requesterName,
        String storeName,
        String deliveryPlace,
        String orderTime
) {
}
