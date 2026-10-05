package com.example.capstone.api;

import com.example.capstone.domain.notification.NotificationSendHistory;
import com.example.capstone.dto.ApiEnvelope;
import com.example.capstone.dto.notification.FcmTokenDeleteRequestDto;
import com.example.capstone.dto.notification.FcmTokenRegisterRequestDto;
import com.example.capstone.dto.notification.NotificationResponseDto;
import com.example.capstone.repository.NotificationSendHistoryRepository;
import com.example.capstone.service.FcmService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Parameters;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/notifications")
@Tag(name = "알림 API", description = "알림 목록 조회 및 푸시 토큰 관리 API")
public class NotificationController {

    private final FcmService fcmService;
    private final NotificationSendHistoryRepository notificationRepository;

    @Operation(
            summary = "알림 목록 조회",
            description = "로그인한 사용자의 알림 목록을 조회합니다.",
            security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
            @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @GetMapping
    public ApiEnvelope<List<NotificationResponseDto>> getNotifications(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId
    ) {
        List<NotificationSendHistory> notifications = notificationRepository.findByUserIdOrderByCreatedAtDesc(userId);
        List<NotificationResponseDto> response = notifications.stream()
                .map(NotificationResponseDto::from)
                .collect(Collectors.toList());
        return ApiEnvelope.ok(response);
    }

    @Operation(
            summary = "FCM 토큰 등록",
            description = "로그인한 사용자의 디바이스 FCM 토큰을 등록합니다.",
            security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
            @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
            @ApiResponse(responseCode = "204", description = "등록 성공"),
            @ApiResponse(responseCode = "400", description = "요청 데이터 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @PostMapping("/tokens")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void registerToken(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @RequestBody @Valid FcmTokenRegisterRequestDto request
    ) {
        fcmService.registerToken(userId, request.token(), request.deviceId());
    }

    @Operation(
            summary = "FCM 토큰 삭제",
            description = "로그아웃 시 디바이스 FCM 토큰을 삭제합니다.",
            security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
            @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
            @ApiResponse(responseCode = "204", description = "삭제 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @DeleteMapping("/tokens")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteToken(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @RequestBody @Valid FcmTokenDeleteRequestDto request
    ) {
        fcmService.removeToken(userId, request.token());
    }

    @Operation(
            summary = "모든 알림 읽음 처리",
            description = "로그인한 사용자의 모든 알림을 읽음 처리합니다.",
            security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
            @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "읽음 처리 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @PutMapping("/read-all")
    @Transactional
    public ApiEnvelope<Void> markAllAsRead(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId
    ) {
        notificationRepository.markAllAsReadByUserId(userId);
        return ApiEnvelope.ok(null);
    }

    @Operation(
            summary = "특정 알림 읽음 처리",
            description = "특정 알림을 읽음 처리합니다.",
            security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
            @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "읽음 처리 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @PutMapping("/{notificationId}/read")
    @Transactional
    public ApiEnvelope<Void> markAsRead(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long notificationId
    ) {
        notificationRepository.markAsReadByIdAndUserId(notificationId, userId);
        return ApiEnvelope.ok(null);
    }
}
