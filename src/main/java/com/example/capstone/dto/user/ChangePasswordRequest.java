package com.example.capstone.dto.user;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@Schema(description = "비밀번호 변경 요청")
public class ChangePasswordRequest {

    @Schema(description = "현재 비밀번호", example = "OldPass123!@#", required = true)
    @NotBlank(message = "현재 비밀번호를 입력해주세요")
    @JsonProperty("current_password")
    private String currentPassword;

    @Schema(description = "새 비밀번호 (영문, 숫자, 특수문자 포함 8자 이상)", example = "NewPass456!@#", required = true)
    @NotBlank(message = "새 비밀번호를 입력해주세요")
    @Size(min = 8, message = "비밀번호는 최소 8자 이상이어야 합니다")
    @Pattern(
        regexp = "^(?=.*[A-Za-z])(?=.*\\d)(?=.*[@$!%*#?&])[A-Za-z\\d@$!%*#?&]{8,}$",
        message = "비밀번호는 영문, 숫자, 특수문자(@$!%*#?&)를 각각 포함해야 합니다"
    )
    @JsonProperty("new_password")
    private String newPassword;
}
