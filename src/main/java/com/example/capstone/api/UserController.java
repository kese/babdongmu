package com.example.capstone.api;

import com.example.capstone.dto.ApiEnvelope;
import com.example.capstone.dto.user.ChangePasswordRequest;
import com.example.capstone.dto.user.ProfileImageResponse;
import com.example.capstone.dto.user.UpdateProfileRequest;
import com.example.capstone.dto.user.UserDeliveryStatsResponseDto;
import com.example.capstone.dto.user.UserPointsResponseDto;
import com.example.capstone.dto.user.UserProfileResponseDto;
import com.example.capstone.service.MyPageService;
import com.example.capstone.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Parameters;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/user")
@Tag(name = "User", description = "마이페이지 관련 API")
public class UserController {

    private final MyPageService myPageService;
    private final UserService userService;

    @Operation(
        summary = "사용자 프로필 조회",
        description = "로그인한 사용자의 기본 프로필 정보를 반환합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "프로필 조회 성공",
            content = @Content(schema = @Schema(implementation = UserProfileResponseDto.class))),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "404", description = "사용자를 찾을 수 없음")
    })
    @GetMapping("/profile")
    public ResponseEntity<ApiEnvelope<UserProfileResponseDto>> getProfile(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        UserProfileResponseDto profile = myPageService.getProfile(userId);
        return ResponseEntity.ok(ApiEnvelope.ok(profile));
    }

    @Operation(
        summary = "포인트 조회",
        description = "현재 적립된 포인트를 조회합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "포인트 조회 성공",
            content = @Content(schema = @Schema(implementation = UserPointsResponseDto.class))),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @GetMapping("/points")
    public ResponseEntity<ApiEnvelope<UserPointsResponseDto>> getPoints(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        UserPointsResponseDto points = myPageService.getPoints(userId);
        return ResponseEntity.ok(ApiEnvelope.ok(points));
    }

    @Operation(
        summary = "배달 통계 조회",
        description = "참여한 배달 모집 기반의 요약 통계를 제공합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "배달 통계 조회 성공",
            content = @Content(schema = @Schema(implementation = UserDeliveryStatsResponseDto.class))),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @GetMapping("/delivery-stats")
    public ResponseEntity<ApiEnvelope<UserDeliveryStatsResponseDto>> getDeliveryStats(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        UserDeliveryStatsResponseDto stats = myPageService.getDeliveryStats(userId);
        return ResponseEntity.ok(ApiEnvelope.ok(stats));
    }

    @Operation(
        summary = "로그아웃",
        description = "서버 측 로그 이벤트를 기록하고 성공 메시지를 반환합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "로그아웃 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @PostMapping("/logout")
    public ResponseEntity<ApiEnvelope<Void>> logout(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            HttpServletRequest request) {
        myPageService.logout(userId, request.getRemoteAddr(), request.getHeader("User-Agent"));
        return ResponseEntity.ok(ApiEnvelope.ok("로그아웃되었습니다.", null));
    }

    @Operation(
        summary = "프로필 정보 수정",
        description = "사용자 프로필 정보를 수정합니다. 변경하고 싶은 필드만 포함하면 됩니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "프로필 수정 성공",
            content = @Content(schema = @Schema(implementation = UserProfileResponseDto.class))),
        @ApiResponse(responseCode = "400", description = "잘못된 요청 (유효성 검사 실패, 중복된 닉네임/이메일 등)"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @PutMapping("/profile")
    public ResponseEntity<ApiEnvelope<UserProfileResponseDto>> updateProfile(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @Valid @RequestBody UpdateProfileRequest request) {
        UserProfileResponseDto profile = userService.updateProfile(userId, request);
        return ResponseEntity.ok(ApiEnvelope.ok("프로필이 수정되었습니다", profile));
    }

    @Operation(
        summary = "비밀번호 변경",
        description = "현재 비밀번호를 확인 후 새 비밀번호로 변경합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "비밀번호 변경 성공"),
        @ApiResponse(responseCode = "400", description = "현재 비밀번호 불일치 또는 유효성 검사 실패"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @PutMapping("/password")
    public ResponseEntity<ApiEnvelope<Void>> changePassword(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @Valid @RequestBody ChangePasswordRequest request) {
        userService.changePassword(userId, request);
        return ResponseEntity.ok(ApiEnvelope.ok("비밀번호가 변경되었습니다", null));
    }

    @Operation(
        summary = "프로필 이미지 업로드",
        description = "프로필 이미지를 업로드합니다. 최대 10MB, JPG/PNG/GIF 형식만 허용됩니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "이미지 업로드 성공",
            content = @Content(schema = @Schema(implementation = ProfileImageResponse.class))),
        @ApiResponse(responseCode = "400", description = "잘못된 파일 형식 또는 파일 없음"),
        @ApiResponse(responseCode = "413", description = "파일 크기 초과 (10MB)"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @PostMapping(value = "/profile/image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiEnvelope<ProfileImageResponse>> uploadProfileImage(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @Parameter(description = "프로필 이미지 파일") @RequestParam("image") MultipartFile image) {
        ProfileImageResponse response = userService.uploadProfileImage(userId, image);
        return ResponseEntity.ok(ApiEnvelope.ok("프로필 이미지가 업로드되었습니다", response));
    }

    @Operation(
        summary = "회원 탈퇴",
        description = "회원 탈퇴를 진행합니다. 탈퇴 후 모든 데이터는 복구할 수 없습니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "회원 탈퇴 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @DeleteMapping("/account")
    public ResponseEntity<ApiEnvelope<Void>> deleteAccount(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        userService.deleteAccount(userId);
        return ResponseEntity.ok(ApiEnvelope.ok("회원 탈퇴가 완료되었습니다", null));
    }
}
