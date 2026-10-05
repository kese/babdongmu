package com.example.capstone.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
@Schema(description = "회원가입 요청")
public class SignupRequest {

    @Schema(description = "이메일 주소", example = "user@example.com", required = true)
    @Email
    @NotBlank
    private String email;

    @Schema(description = "비밀번호 (최소 4자)", example = "password123", required = true)
    @NotBlank
    @Size(min = 4, message = "비밀번호는 최소 4자 이상이어야 합니다.")
    private String password;

    @Schema(description = "사용자 이름", example = "홍길동", required = true)
    @NotBlank
    @Size(max = 50)
    @JsonAlias("name")
    private String username;

    @Schema(description = "전화번호 (E.164 형식, 선택)", example = "+821000000000", required = false)
    @Pattern(regexp = "^$|^[+][1-9][0-9]{1,14}$", message = "전화번호는 E.164 형식이어야 합니다.")
    private String phoneNumber;

    @Schema(description = "프로필 이미지 URL (선택)", example = "https://example.com/profile.jpg", required = false)
    @Size(max = 255)
    private String profileImageUrl;

    @Schema(description = "닉네임", example = "길동이", required = true)
    @NotBlank
    @Size(max = 50)
    private String nickname;

    @Schema(description = "위도 (선택)", example = "37.566536", required = false)
    private BigDecimal locationLatitude;

    @Schema(description = "경도 (선택)", example = "126.977966", required = false)
    private BigDecimal locationLongitude;
}


