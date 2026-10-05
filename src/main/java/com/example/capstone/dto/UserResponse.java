package com.example.capstone.dto;

import com.example.capstone.domain.User;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
@Schema(description = "사용자 정보 응답")
public class UserResponse {
    @Schema(description = "사용자 ID", example = "1")
    private Long userId;

    @Schema(description = "이메일 주소", example = "user@example.com")
    private String email;

    @Schema(description = "사용자 이름", example = "홍길동")
    private String username;

    @Schema(description = "닉네임", example = "길동이")
    private String nickname;

    @Schema(description = "전화번호", example = "+821000000000")
    private String phoneNumber;

    @Schema(description = "프로필 이미지 URL", example = "https://example.com/profile.jpg")
    private String profileImageUrl;

    @Schema(description = "위도", example = "37.566536")
    private BigDecimal locationLatitude;

    @Schema(description = "경도", example = "126.977966")
    private BigDecimal locationLongitude;

    @Schema(description = "활성화 여부", example = "true")
    private Boolean isActive;

    @Schema(description = "포인트", example = "100")
    private Integer point;

    @Schema(description = "생성 일시", example = "2025-10-13T12:34:56")
    private LocalDateTime createdAt;

    @Schema(description = "수정 일시", example = "2025-10-13T12:34:56")
    private LocalDateTime updatedAt;

    @Schema(description = "삭제 일시", example = "2025-10-20T09:15:00")
    private LocalDateTime deletedAt;

    public static UserResponse from(User user) {
        return UserResponse.builder()
                .userId(user.getId())
                .email(user.getEmail())
                .username(user.getUsername())
                .nickname(user.getNickname())
                .phoneNumber(user.getPhoneNumber())
                .profileImageUrl(user.getProfileImageUrl())
                .locationLatitude(user.getLocationLatitude())
                .locationLongitude(user.getLocationLongitude())
                .isActive(user.getIsActive())
                .point(user.getPoint())
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .deletedAt(user.getDeletedAt())
                .build();
    }
}


