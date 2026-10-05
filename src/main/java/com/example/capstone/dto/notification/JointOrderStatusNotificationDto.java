package com.example.capstone.dto.notification;

public record JointOrderStatusNotificationDto(
        Long requestId,
        Long postId,
        String status,
        Long chatRoomId,
        String storeName,
        String deliveryPlace
) {
}
