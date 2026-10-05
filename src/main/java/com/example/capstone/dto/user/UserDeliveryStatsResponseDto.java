package com.example.capstone.dto.user;

/**
 * 배달 통계 응답 DTO.
 */
public record UserDeliveryStatsResponseDto(
        long totalOrders,
        long totalDeliveryFeeSaved,
        long totalDeliveryFeePaid,
        long originalDeliveryFee
) {

    public static UserDeliveryStatsResponseDto empty() {
        return new UserDeliveryStatsResponseDto(0L, 0L, 0L, 0L);
    }
}
