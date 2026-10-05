package com.example.capstone.dto.chat;

import com.example.capstone.domain.User;
import com.example.capstone.domain.chat.ChatMessage;
import com.example.capstone.domain.chat.MessageType;
import com.example.capstone.dto.sharedcart.SharedCartSummaryResponseDto;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import java.time.LocalDateTime;

public record ChatMessageResponseDto(
        Long messageId,
        Long senderId,
        String senderNickname,
        String messageContent,
        String messageType,
        LocalDateTime sentAt,
                boolean mine,
                SharedCartSummaryResponseDto cartSummary
) {
        private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
                        .registerModule(new JavaTimeModule())
                        .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    public static ChatMessageResponseDto of(ChatMessage message, Long currentUserId) {
        User sender = message.getSender();
        Long resolvedSenderId = sender != null ? sender.getId() : null;
        String resolvedNickname = sender != null ? sender.getNickname() : null;
        String resolvedType = message.getMessageType() != null
                ? message.getMessageType().getDbValue()
                : MessageType.TEXT.getDbValue();
        boolean mine = currentUserId != null && resolvedSenderId != null && resolvedSenderId.equals(currentUserId);
                SharedCartSummaryResponseDto cartSummary = parseCartSummary(message.getCartSummaryJson());
        return new ChatMessageResponseDto(
                message.getId(),
                resolvedSenderId,
                resolvedNickname,
                message.getMessageContent(),
                resolvedType,
                message.getSentAt(),
                                mine,
                                cartSummary
        );
    }

        private static SharedCartSummaryResponseDto parseCartSummary(String json) {
                if (json == null || json.isBlank()) {
                        return null;
                }
                try {
                        return OBJECT_MAPPER.readValue(json, SharedCartSummaryResponseDto.class);
                } catch (JsonProcessingException ex) {
                        return null;
                }
        }
}
