package com.example.capstone.dto.user;

import com.example.capstone.domain.User;

/**
 * 마이페이지 프로필 응답 DTO.
 */
public record UserProfileResponseDto(
        String name,
        String email,
        String phone,
        String nickname,
        String address,
        String account,
        String profileImage
) {

    public static UserProfileResponseDto from(User user) {
        if (user == null) {
            return new UserProfileResponseDto("", "", "", "", "", "", "");
        }
        return new UserProfileResponseDto(
                safeValue(user.getUsername()),
                safeValue(user.getEmail()),
                safeValue(user.getPhoneNumber()),
                safeValue(user.getNickname()),
                safeValue(user.getAddress()),
                safeValue(user.getAccount()),
                safeValue(user.getProfileImageUrl())
        );
    }

    private static String safeValue(String source) {
        return source != null ? source : "";
    }
}
