package com.example.capstone.dto.user;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@Schema(description = "프로필 수정 요청")
public class UpdateProfileRequest {

    @Schema(description = "사용자 이름", example = "홍길동")
    @Size(max = 50, message = "이름은 50자 이하여야 합니다")
    private String name;

    @Schema(description = "닉네임", example = "길동이")
    @Size(min = 2, max = 50, message = "닉네임은 2자 이상 50자 이하여야 합니다")
    private String nickname;

    @Schema(description = "전화번호 (E.164 형식)", example = "+821000000000")
    @Pattern(regexp = "^$|^[+][1-9][0-9]{1,14}$", message = "전화번호는 E.164 형식이어야 합니다")
    private String phone;

    @Schema(description = "이메일 주소", example = "user@example.com")
    @Email(message = "올바른 이메일 형식이어야 합니다")
    private String email;

    @Schema(description = "주소", example = "충북 충주시 대학로 50")
    @Size(max = 255, message = "주소는 255자 이하여야 합니다")
    private String address;

    @Schema(description = "계좌번호 (포인트 출금용)", example = "1234567890")
    @Size(max = 50, message = "계좌번호는 50자 이하여야 합니다")
    private String account;
}
