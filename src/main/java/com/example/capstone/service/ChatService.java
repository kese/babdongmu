package com.example.capstone.service;

import com.example.capstone.domain.User;
import com.example.capstone.domain.chat.ChatMessage;
import com.example.capstone.domain.chat.ChatRoomParticipant;
import com.example.capstone.domain.chat.MessageType;
import com.example.capstone.config.WebSocketConfig;
import com.example.capstone.dto.chat.ChatMessagePageResponseDto;
import com.example.capstone.dto.chat.ChatMessageResponseDto;
import com.example.capstone.dto.chat.ChatMessageSendRequestDto;
import com.example.capstone.dto.chat.ChatRoomListResponseDto;
import com.example.capstone.exception.ForbiddenException;
import com.example.capstone.repository.ChatMessageRepository;
import com.example.capstone.repository.ChatRoomParticipantRepository;
import com.example.capstone.repository.ChatRoomRepository;
import com.example.capstone.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Slice;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.util.StringUtils;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class ChatService {

    private static final int DEFAULT_PAGE_SIZE = 20;
    private static final int MAX_PAGE_SIZE = 50;

    private final ChatRoomParticipantRepository chatRoomParticipantRepository;
        private final ChatMessageRepository chatMessageRepository;
        private final ChatRoomRepository chatRoomRepository;
        private final UserRepository userRepository;
        private final SimpMessagingTemplate messagingTemplate;
        private final FcmService fcmService;

    @Transactional(readOnly = true)
    public List<ChatRoomListResponseDto> findMyRooms(Long userId) {
        if (userId == null) {
            throw new EntityNotFoundException("사용자 정보를 확인할 수 없습니다.");
        }
        List<ChatRoomParticipant> participations = chatRoomParticipantRepository.findByUserIdWithRoom(userId);
        if (participations.isEmpty()) {
            return Collections.emptyList();
        }

        Set<Long> roomIds = participations.stream()
                .map(participation -> participation.getChatRoom().getId())
                .collect(Collectors.toSet());

        Map<Long, Integer> memberCounts = chatRoomParticipantRepository.countMembersByRoomIds(roomIds).stream()
                .collect(Collectors.toMap(
                        ChatRoomParticipantRepository.ChatRoomMemberCount::getRoomId,
                        entry -> entry.getMemberCount().intValue()
                ));

        Map<Long, ChatMessage> latestMessages = chatMessageRepository.findLatestMessagesByRoomIds(roomIds).stream()
                .collect(Collectors.toMap(message -> message.getChatRoom().getId(), message -> message));

        Map<Long, Long> totalMessageCounts = chatMessageRepository.countMessagesByRoomIds(roomIds).stream()
                .collect(Collectors.toMap(
                        ChatMessageRepository.ChatMessageCount::getRoomId,
                        ChatMessageRepository.ChatMessageCount::getTotalCount
                ));

        List<ChatRoomListResponseDto> results = new ArrayList<>();
        for (ChatRoomParticipant participation : participations) {
            Long roomId = participation.getChatRoom().getId();
            ChatMessage lastMessage = latestMessages.get(roomId);
            long unreadCount;
            Long lastReadMessageId = participation.getLastReadMessageId();
            if (lastMessage == null) {
                unreadCount = 0L;
            } else if (lastReadMessageId == null) {
                unreadCount = totalMessageCounts.getOrDefault(roomId, 0L);
            } else {
                unreadCount = chatMessageRepository.countByChatRoom_IdAndIdGreaterThan(roomId, lastReadMessageId);
            }
            results.add(ChatRoomListResponseDto.of(
                    participation,
                    lastMessage,
                    unreadCount,
                    memberCounts.getOrDefault(roomId, 0)
            ));
        }

        results.sort(Comparator.comparing(ChatRoomListResponseDto::getLastMessageAt,
                Comparator.nullsLast(Comparator.reverseOrder())));
        return results;
    }

    @Transactional(readOnly = true)
    public ChatMessagePageResponseDto findMessages(Long userId,
                                                   Long roomId,
                                                   Long cursorMessageId,
                                                   Integer requestedSize) {
        if (userId == null) {
            throw new EntityNotFoundException("사용자 정보를 확인할 수 없습니다.");
        }

        int size = (requestedSize == null || requestedSize <= 0) ? DEFAULT_PAGE_SIZE
                : Math.min(requestedSize, MAX_PAGE_SIZE);

                ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);

        PageRequest pageRequest = PageRequest.of(0, size, Sort.by(Sort.Direction.DESC, "id"));

        Long targetRoomId = participation.getChatRoom().getId();
        Slice<ChatMessage> slice = cursorMessageId == null
                ? chatMessageRepository.findByChatRoom_IdOrderByIdDesc(targetRoomId, pageRequest)
                : chatMessageRepository.findByChatRoom_IdAndIdLessThanOrderByIdDesc(targetRoomId, cursorMessageId, pageRequest);

        List<ChatMessage> messages = new ArrayList<>(slice.getContent());
        messages.sort(Comparator.comparing(ChatMessage::getId));

        List<ChatMessageResponseDto> responseMessages = messages.stream()
                .map(message -> ChatMessageResponseDto.of(message, userId))
                .collect(Collectors.toList());

        Long nextCursor = (slice.hasNext() && !responseMessages.isEmpty())
                ? responseMessages.getFirst().messageId()
                : null;

        return ChatMessagePageResponseDto.of(responseMessages, slice.hasNext(), nextCursor);
    }

        @Transactional
        public ChatMessageResponseDto sendMessage(Long userId,
                                                                                          Long roomId,
                                                                                          ChatMessageSendRequestDto request) {
                if (userId == null) {
                        throw new EntityNotFoundException("사용자 정보를 확인할 수 없습니다.");
                }
                if (request == null || !StringUtils.hasText(request.messageContent())) {
                        throw new IllegalArgumentException("메시지 내용을 입력하세요.");
                }

                ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
                User sender = userRepository.findById(userId)
                                .orElseThrow(() -> new EntityNotFoundException("사용자 정보를 찾을 수 없습니다."));

                MessageType messageType = resolveMessageType(request.messageType());

                ChatMessage savedMessage = chatMessageRepository.save(ChatMessage.builder()
                                .chatRoom(participation.getChatRoom())
                                .sender(sender)
                                .messageContent(request.messageContent())
                                .messageType(messageType)
                                .build());

                ChatMessageResponseDto responseDto = ChatMessageResponseDto.of(savedMessage, userId);
                Long chatRoomId = participation.getChatRoom().getId();
                List<Long> recipientIds = chatRoomParticipantRepository.findUserIdsByChatRoomId(chatRoomId).stream()
                                .filter(participantId -> !participantId.equals(userId))
                                .toList();

                executeAfterCommit(() -> {
                        publishToWebSocket(chatRoomId, responseDto);
                        if (!recipientIds.isEmpty()) {
                                try {
                                        fcmService.sendChatMessageNotification(savedMessage, chatRoomId, recipientIds);
                                } catch (Exception ex) {
                                        log.warn("채팅 메시지 FCM 전송 실패. roomId={}, messageId={}", chatRoomId, savedMessage.getId(), ex);
                                }
                        }
                });

                return responseDto;
        }

        private ChatRoomParticipant getParticipationOrThrow(Long roomId, Long userId) {
                return chatRoomParticipantRepository
                                .findByChatRoom_IdAndUser_Id(roomId, userId)
                                .orElseGet(() -> {
                                        if (!chatRoomRepository.existsById(roomId)) {
                                                throw new EntityNotFoundException("채팅방 정보를 찾을 수 없습니다.");
                                        }
                                        throw new ForbiddenException("채팅방에 접근할 권한이 없습니다.");
                                });
        }

        private MessageType resolveMessageType(String rawType) {
                if (!StringUtils.hasText(rawType)) {
                        return MessageType.TEXT;
                }
                try {
                        return MessageType.fromDbValue(rawType);
                } catch (IllegalArgumentException ex) {
                        throw new IllegalArgumentException("지원하지 않는 메시지 타입입니다: " + rawType);
                }
        }

        private void publishToWebSocket(Long roomId, ChatMessageResponseDto payload) {
                try {
                        messagingTemplate.convertAndSend(buildChatDestination(roomId), payload);
                } catch (Exception ex) {
                        log.warn("웹소켓 메시지 전송 실패. roomId={}, messageId={}", roomId, payload.messageId(), ex);
                }
        }

        private String buildChatDestination(Long roomId) {
                return WebSocketConfig.CHAT_TOPIC_PREFIX + "/chat.rooms." + roomId;
        }

        private void executeAfterCommit(Runnable task) {
                if (!TransactionSynchronizationManager.isSynchronizationActive()) {
                        task.run();
                        return;
                }
                TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                                task.run();
                        }
                });
        }

        @Transactional
        public void leaveRoom(Long userId, Long roomId) {
                if (userId == null) {
                        throw new EntityNotFoundException("사용자 정보를 확인할 수 없습니다.");
                }

                ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
                User user = participation.getUser();
                if (user == null) {
                        throw new EntityNotFoundException("사용자 정보를 찾을 수 없습니다.");
                }

                if (participation.getChatRoom().getPost() != null
                                && participation.getChatRoom().getPost().getAuthor() != null
                                && userId.equals(participation.getChatRoom().getPost().getAuthor().getId())) {
                        throw new IllegalStateException("방장은 채팅방을 나갈 수 없습니다.");
                }

                Long chatRoomId = participation.getChatRoom().getId();
                List<Long> recipientIds = chatRoomParticipantRepository.findUserIdsByChatRoomId(chatRoomId).stream()
                                .filter(id -> !id.equals(userId))
                                .toList();

                chatRoomParticipantRepository.delete(participation);

                ChatMessage leaveMessage = chatMessageRepository.save(ChatMessage.builder()
                                .chatRoom(participation.getChatRoom())
                                .sender(user)
                                .messageContent(buildLeaveMessage(user))
                                .messageType(MessageType.SYSTEM)
                                .build());

                ChatMessageResponseDto payload = ChatMessageResponseDto.of(leaveMessage, userId);

                executeAfterCommit(() -> {
                        publishToWebSocket(chatRoomId, payload);
                        if (!recipientIds.isEmpty()) {
                                try {
                                        fcmService.sendChatMessageNotification(leaveMessage, chatRoomId, recipientIds);
                                } catch (Exception ex) {
                                        log.warn("채팅방 나가기 FCM 전송 실패. roomId={}, messageId={}", chatRoomId, leaveMessage.getId(), ex);
                                }
                        }
                });
        }

        private String buildLeaveMessage(User user) {
                String nickname = user != null ? user.getNickname() : null;
                if (StringUtils.hasText(nickname)) {
                        return nickname + "님이 채팅방을 떠났습니다.";
                }
                return "참여자가 채팅방을 떠났습니다.";
        }
}
