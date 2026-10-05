package com.example.capstone.api;

import com.example.capstone.dto.ApiEnvelope;
import com.example.capstone.dto.chat.ChatRoomBasicInfoResponseDto;
import com.example.capstone.dto.sharedcart.FinalizeOrderRequestDto;
import com.example.capstone.dto.sharedcart.SettlementRequestCreateRequestDto;
import com.example.capstone.dto.sharedcart.SettlementRequestDecisionRequestDto;
import com.example.capstone.dto.sharedcart.SettlementRequestListResponseDto;
import com.example.capstone.dto.sharedcart.SettlementRequestResponseDto;
import com.example.capstone.dto.sharedcart.SettlementTransferRequestDto;
import com.example.capstone.dto.sharedcart.SettlementTransferResponseDto;
import com.example.capstone.dto.sharedcart.SharedCartItemRequestDto;
import com.example.capstone.dto.sharedcart.SharedCartItemResponseDto;
import com.example.capstone.dto.sharedcart.SharedCartResponseDto;
import com.example.capstone.dto.sharedcart.SharedCartSummaryResponseDto;
import com.example.capstone.service.SharedCartService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/chat/rooms")
@Tag(name = "공용 장바구니", description = "채팅방 공용 장바구니 API")
public class SharedCartController {

    private final SharedCartService sharedCartService;

    @Operation(summary = "채팅방 기본 정보 조회", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "채팅방 정보 조회 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "채팅방 접근 권한 없음")
    })
    @GetMapping("/{roomId}")
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> getRoomBasicInfo(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId) {
        return sharedCartService.findRoomBasicInfo(userId, roomId);
    }

    @Operation(summary = "공용 장바구니 활성화", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "장바구니 활성화 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "채팅방 없음")
    })
    @PostMapping("/{roomId}/shared-cart/activate")
    public ApiEnvelope<SharedCartResponseDto> activateSharedCart(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId) {
        return sharedCartService.activate(userId, roomId);
    }

    @Operation(summary = "공용 장바구니 조회", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "장바구니 조회 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "접근 권한 없음")
    })
    @GetMapping("/{roomId}/shared-cart")
    public ApiEnvelope<SharedCartResponseDto> getSharedCart(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId) {
        return sharedCartService.findCart(userId, roomId);
    }

    @Operation(summary = "장바구니 항목 추가", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "항목 추가 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "참여자/장바구니 없음")
    })
    @PostMapping("/{roomId}/shared-cart/items")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiEnvelope<SharedCartItemResponseDto> addItem(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId,
            @RequestBody @Valid SharedCartItemRequestDto request) {
        return sharedCartService.addItem(userId, roomId, request);
    }

    @Operation(summary = "장바구니 항목 수정", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "항목 수정 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "항목 없음")
    })
    @PutMapping("/{roomId}/shared-cart/items/{itemId}")
    public ApiEnvelope<SharedCartItemResponseDto> updateItem(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId,
            @PathVariable Long itemId,
            @RequestBody @Valid SharedCartItemRequestDto request) {
        return sharedCartService.updateItem(userId, roomId, itemId, request);
    }

    @Operation(summary = "장바구니 항목 삭제", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "204", description = "항목 삭제 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "항목 없음")
    })
    @DeleteMapping("/{roomId}/shared-cart/items/{itemId}")
    public ResponseEntity<Void> deleteItem(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId,
            @PathVariable Long itemId) {
        sharedCartService.deleteItem(userId, roomId, itemId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "공용 장바구니 주문 완료", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "주문 완료"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "장바구니 없음")
    })
    @PostMapping("/{roomId}/shared-cart/complete")
    public ApiEnvelope<SharedCartSummaryResponseDto> complete(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId) {
        return sharedCartService.complete(userId, roomId);
    }

    @Operation(summary = "주문 확정", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "주문 확정 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "장바구니 없음")
    })
    @PostMapping("/{roomId}/finalize_order")
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> finalizeOrder(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId,
            @RequestBody @Valid FinalizeOrderRequestDto request) {
        return sharedCartService.finalizeOrder(userId, roomId, request);
    }

    @Operation(summary = "배달 시작", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "배달 시작 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "채팅방 없음")
    })
    @PostMapping("/{roomId}/start_delivery")
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> startDelivery(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId) {
        return sharedCartService.startDelivery(userId, roomId);
    }

        @Operation(summary = "안전 거래 가이드 동의", description = "배달 진행 중에 참여자가 안전 거래 가이드를 동의하면 채팅 입력이 가능해집니다.", security = @SecurityRequirement(name = "bearerAuth"))
        @ApiResponses({
                        @ApiResponse(responseCode = "200", description = "동의 처리 성공"),
                        @ApiResponse(responseCode = "400", description = "요청 오류"),
                        @ApiResponse(responseCode = "401", description = "인증 실패"),
                        @ApiResponse(responseCode = "403", description = "권한 없음"),
                        @ApiResponse(responseCode = "404", description = "채팅방 없음")
        })
        @PostMapping("/{roomId}/accept_guide")
        public ApiEnvelope<ChatRoomBasicInfoResponseDto> acceptDeliveryGuide(
                        @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
                        @PathVariable Long roomId) {
                return sharedCartService.acceptDeliveryGuide(userId, roomId);
        }

    @Operation(summary = "수령 확인", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "수령 확인 갱신"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "채팅방 없음")
    })
    @PostMapping("/{roomId}/confirm_reception")
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> confirmReception(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId) {
        return sharedCartService.confirmReception(userId, roomId);
    }

    @Operation(summary = "문제 신고", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "문제 신고 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "채팅방 없음")
    })
    @PostMapping("/{roomId}/report_issue")
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> reportIssue(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId) {
        return sharedCartService.reportIssue(userId, roomId);
    }

    @Operation(summary = "참가자별 커스텀 정산", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "정산 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "장바구니 없음")
    })
    @PostMapping("/{roomId}/settlement/transfer")
    public ApiEnvelope<SettlementTransferResponseDto> transferSettlement(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId,
            @RequestBody @Valid SettlementTransferRequestDto request) {
        return sharedCartService.transferSettlement(userId, roomId, request);
    }

    @Operation(summary = "참여자 송금 요청 생성", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "송금 요청 생성 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "장바구니 없음")
    })
    @PostMapping("/{roomId}/settlement/transfer/requests")
    public ApiEnvelope<SettlementRequestResponseDto> requestSettlementTransfer(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId,
            @RequestBody @Valid SettlementRequestCreateRequestDto request) {
        return sharedCartService.createSettlementRequest(userId, roomId, request);
    }

    @Operation(summary = "송금 요청 목록 조회", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "송금 요청 목록 조회 성공"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "장바구니 없음")
    })
    @GetMapping("/{roomId}/settlement/transfer/requests")
    public ApiEnvelope<SettlementRequestListResponseDto> getSettlementRequests(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId) {
        return sharedCartService.getSettlementRequests(userId, roomId);
    }

    @Operation(summary = "송금 요청 승인", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "송금 요청 승인 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "요청 없음")
    })
    @PostMapping("/{roomId}/settlement/transfer/requests/{requestId}/approve")
    public ApiEnvelope<SettlementRequestResponseDto> approveSettlementRequest(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId,
            @PathVariable Long requestId,
            @RequestBody(required = false) SettlementRequestDecisionRequestDto request) {
        return sharedCartService.approveSettlementRequest(userId, roomId, requestId, request);
    }

    @Operation(summary = "송금 요청 거절", description = "방장 또는 요청자가 직접 거절/취소할 수 있습니다.", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "송금 요청 거절 성공"),
            @ApiResponse(responseCode = "400", description = "요청 오류"),
            @ApiResponse(responseCode = "401", description = "인증 실패"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "요청 없음")
    })
    @PostMapping("/{roomId}/settlement/transfer/requests/{requestId}/reject")
    public ApiEnvelope<SettlementRequestResponseDto> rejectSettlementRequest(
            @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
            @PathVariable Long roomId,
            @PathVariable Long requestId,
            @RequestBody(required = false) SettlementRequestDecisionRequestDto request) {
        return sharedCartService.rejectSettlementRequest(userId, roomId, requestId, request);
    }
}
