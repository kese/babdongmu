package com.example.capstone.api;

import com.example.capstone.dto.chat.ChatMessageSendRequestDto;
import com.example.capstone.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;

@Controller
@RequiredArgsConstructor
public class ChatMessageWebSocketController {

    private final ChatService chatService;

    @MessageMapping("/chat.rooms.{roomId}/send")
    public void handleSend(@DestinationVariable Long roomId,
                           @Payload @Valid ChatMessageSendRequestDto request,
                           Authentication authentication) {
        if (authentication == null || authentication.getPrincipal() == null) {
            throw new IllegalArgumentException("인증 정보를 확인할 수 없습니다.");
        }
        Object principal = authentication.getPrincipal();
        if (!(principal instanceof Long userId)) {
            throw new IllegalArgumentException("유효하지 않은 인증 정보입니다.");
        }
        chatService.sendMessage(userId, roomId, request);
    }
}
