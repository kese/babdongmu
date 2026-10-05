package com.example.capstone.api;

import com.example.capstone.dto.ApiEnvelope;
import com.example.capstone.dto.jointorder.*;
import com.example.capstone.service.JointOrderService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/joint-orders")
@Tag(name = "Joint Order", description = "합동 주문 매칭 및 관리 API")
public class JointOrderController {

    private final JointOrderService jointOrderService;

    @Operation(
        summary = "사용자 게시글 정보 조회",
        description = "요청자가 매칭 가능한 게시글을 가지고 있는지 확인합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @GetMapping("/my-post")
    public ResponseEntity<ApiEnvelope<MyPostResponseDto>> getMyPost(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        MyPostResponseDto response = jointOrderService.getMyMatchablePost(userId);
        return ResponseEntity.ok(ApiEnvelope.ok(response));
    }

    @Operation(
        summary = "매칭 가능 게시글 검색",
        description = "동일한 조건의 다른 게시글 목록을 조회합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @GetMapping("/matchable")
    public ResponseEntity<ApiEnvelope<List<MatchablePostDto>>> getMatchablePosts(
            @Parameter(description = "음식점 이름") @RequestParam String storeName,
            @Parameter(description = "배달 장소 (POI 명칭)") @RequestParam String locationName,
            @Parameter(description = "배달비") @RequestParam Integer deliveryFee,
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        List<MatchablePostDto> response = jointOrderService.getMatchablePosts(storeName, locationName, deliveryFee, userId);
        return ResponseEntity.ok(ApiEnvelope.ok(response));
    }

    @Operation(
        summary = "합동 주문 요청 생성",
        description = "선택한 게시글들에 합동 주문 요청을 전송합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @PostMapping("/request")
    public ResponseEntity<ApiEnvelope<JointOrderRequestResponseDto>> createJointOrderRequest(
            @Valid @RequestBody CreateJointOrderRequestDto request,
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        JointOrderRequestResponseDto response = jointOrderService.createJointOrderRequest(request, userId);
        return ResponseEntity.ok(ApiEnvelope.ok(response));
    }

    @Operation(
        summary = "요청 상태 확인",
        description = "실시간 상태 확인을 위한 폴링 엔드포인트입니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @GetMapping("/request/{requestId}")
    public ResponseEntity<ApiEnvelope<JointOrderStatusDto>> getRequestStatus(
            @Parameter(description = "요청 ID") @PathVariable Long requestId,
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        JointOrderStatusDto response = jointOrderService.getRequestStatus(requestId, userId);
        return ResponseEntity.ok(ApiEnvelope.ok(response));
    }

    @Operation(
        summary = "합동 주문 요청 응답",
        description = "요청받은 합동 주문에 수락/거절 응답을 합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @PostMapping("/request/{requestId}/respond")
    public ResponseEntity<ApiEnvelope<JointOrderResponseDto>> respondToRequest(
            @Parameter(description = "요청 ID") @PathVariable Long requestId,
            @Valid @RequestBody RespondToRequestDto request,
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        JointOrderResponseDto response = jointOrderService.respondToRequest(requestId, request, userId);
        return ResponseEntity.ok(ApiEnvelope.ok(response));
    }

    @Operation(
        summary = "대기 중인 요청 목록 조회",
        description = "사용자에게 온 합동 주문 요청 목록을 조회합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @GetMapping("/requests/pending")
    public ResponseEntity<ApiEnvelope<List<PendingRequestDto>>> getPendingRequests(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        List<PendingRequestDto> response = jointOrderService.getPendingRequests(userId);
        return ResponseEntity.ok(ApiEnvelope.ok(response));
    }

    @Operation(
        summary = "합동 채팅방 생성",
        description = "매칭 성공 시 그룹 채팅방을 생성합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @PostMapping("/create-chat-room")
    public ResponseEntity<ApiEnvelope<CreateChatRoomResponseDto>> createJointChatRoom(
            @Valid @RequestBody CreateChatRoomRequestDto request,
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        CreateChatRoomResponseDto response = jointOrderService.createJointChatRoom(request, userId);
        return ResponseEntity.ok(ApiEnvelope.ok(response));
    }
}
