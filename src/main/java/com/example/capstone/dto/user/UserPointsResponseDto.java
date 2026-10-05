package com.example.capstone.dto.user;

/**
 * 보유 포인트 응답 DTO.
 */
public record UserPointsResponseDto(int points) {

    public static UserPointsResponseDto of(int points) {
        return new UserPointsResponseDto(Math.max(points, 0));
    }
}
