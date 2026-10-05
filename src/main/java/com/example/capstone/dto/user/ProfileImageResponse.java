package com.example.capstone.dto.user;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
@Schema(description = "프로필 이미지 업로드 응답")
public class ProfileImageResponse {

    @Schema(description = "업로드된 이미지 URL", example = "https://example.com/uploads/profile/user123_20241130120000.jpg")
    @JsonProperty("image_url")
    private String imageUrl;
}
