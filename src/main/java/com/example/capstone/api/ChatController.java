package com.example.capstone.api;

import com.example.capstone.dto.chat.ChatMessagePageResponseDto;
import com.example.capstone.dto.chat.ChatMessageResponseDto;
import com.example.capstone.dto.chat.ChatMessageSendRequestDto;
import com.example.capstone.dto.chat.ChatRoomListResponseDto;
import com.example.capstone.service.ChatService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Parameters;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/chat")
@Tag(name = "채팅 API", description = "채팅방 리스트 등 채팅 관련 API")
public class ChatController {

    private final ChatService chatService;

    @Operation(
        summary = "내 채팅방 목록 조회",
        description = """
            ### 사용 방법
            - Swagger UI 우측 상단 `Authorize` 버튼으로 JWT를 등록하거나 `Authorization` 헤더에 직접 `Bearer {JWT}` 값을 넣습니다.
            - 로그인 사용자가 참여 중인 채팅방과 연결된 게시글 정보를 함께 반환합니다.

            ### 주요 응답 필드
            - `lastMessage`: 가장 최근 채팅 메시지 내용
            - `unreadCount`: 사용자가 읽지 않은 메시지 수
            - `memberCount`: 채팅방 전체 사용자 수
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "채팅방 목록 조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패 (JWT 누락 또는 만료)"),
        @ApiResponse(responseCode = "403", description = "접근 권한 없음")
    })
    @GetMapping("/rooms")
    public List<ChatRoomListResponseDto> getMyChatRooms(
        @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        return chatService.findMyRooms(userId);
    }

    @Operation(
        summary = "채팅 메시지 조회",
        description = """
            ### 사용 방법
            - `cursorMessageId` 없이 호출하면 최신 메시지부터 최대 `size`개를 반환합니다.
            - 응답의 `nextCursor` 값을 다음 요청의 `cursorMessageId`로 넘기면 더 이전 메시지를 이어서 조회할 수 있습니다.
            - `mine` 필드는 현재 사용자가 보낸 메시지인지 여부를 나타냅니다.
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "메시지 조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패 (JWT 누락 또는 만료)"),
        @ApiResponse(responseCode = "403", description = "접근 권한 없음"),
        @ApiResponse(responseCode = "404", description = "채팅방 미존재")
    })
    @GetMapping("/rooms/{roomId}/messages")
    public ChatMessagePageResponseDto getRoomMessages(
        @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
        @PathVariable Long roomId,
        @RequestParam(value = "cursorMessageId", required = false) Long cursorMessageId,
        @RequestParam(value = "size", defaultValue = "20") int size
    ) {
        return chatService.findMessages(userId, roomId, cursorMessageId, size);
    }

    @Operation(
        summary = "채팅 메시지 전송",
        description = """
            ### 사용 방법
            - `messageContent` 필드에 전송할 메시지 본문을 담아 요청합니다.
            - `messageType` 을 지정하지 않으면 기본값은 `text` 입니다.
            - 응답으로는 저장된 메시지 정보가 즉시 반환됩니다.
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "메시지 전송 성공"),
        @ApiResponse(responseCode = "400", description = "요청 파라미터 오류"),
        @ApiResponse(responseCode = "401", description = "인증 실패 (JWT 누락 또는 만료)"),
        @ApiResponse(responseCode = "403", description = "채팅방 참여자 아님"),
        @ApiResponse(responseCode = "404", description = "채팅방 또는 사용자 미존재")
    })
    @PostMapping("/rooms/{roomId}/messages")
    @ResponseStatus(HttpStatus.CREATED)
    public ChatMessageResponseDto sendMessage(
        @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
        @PathVariable Long roomId,
        @RequestBody @Valid ChatMessageSendRequestDto request
    ) {
        return chatService.sendMessage(userId, roomId, request);
    }

    @Operation(
        summary = "채팅방 나가기",
        description = "참여자가 채팅방을 떠나면 서버가 참여자 목록에서 제거하고 시스템 메시지를 브로드캐스트합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "204", description = "채팅방 나가기 성공"),
        @ApiResponse(responseCode = "400", description = "요청 오류"),
        @ApiResponse(responseCode = "401", description = "인증 실패 (JWT 누락 또는 만료)"),
        @ApiResponse(responseCode = "403", description = "채팅방 참여자가 아님"),
        @ApiResponse(responseCode = "404", description = "채팅방 또는 사용자 미존재")
    })
    @PostMapping("/rooms/{roomId}/leave")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leaveRoom(
        @Parameter(hidden = true) @AuthenticationPrincipal Long userId,
        @PathVariable Long roomId
    ) {
        chatService.leaveRoom(userId, roomId);
    }
}
