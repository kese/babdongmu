package com.example.capstone.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@Schema(description = "로그인 요청")
public class LoginRequest {

    @Schema(description = "이메일 주소", example = "user@example.com", required = true)
    @Email
    @NotBlank
    private String email;

    @Schema(description = "비밀번호 (최소 4자)", example = "password123", required = true)
    @NotBlank
    @Size(min = 4, message = "비밀번호는 최소 4자 이상이어야 합니다.")
    private String password;
}


