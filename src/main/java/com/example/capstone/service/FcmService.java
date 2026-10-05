package com.example.capstone.service;

import com.example.capstone.config.FirebaseProperties;
import com.example.capstone.domain.User;
import com.example.capstone.domain.chat.ChatMessage;
import com.example.capstone.domain.notification.FcmToken;
import com.example.capstone.domain.notification.NotificationSendHistory;
import com.example.capstone.domain.notification.NotificationType;
import com.example.capstone.dto.notification.JointOrderRequestNotificationDto;
import com.example.capstone.dto.notification.JointOrderStatusNotificationDto;
import com.example.capstone.repository.FcmTokenRepository;
import com.example.capstone.repository.NotificationSendHistoryRepository;
import com.example.capstone.repository.UserRepository;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import jakarta.persistence.EntityNotFoundException;
import java.util.Collection;
import java.util.List;
import java.util.Objects;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class FcmService {

    private final FirebaseProperties firebaseProperties;
    private final FcmTokenRepository fcmTokenRepository;
    private final NotificationSendHistoryRepository notificationSendHistoryRepository;
    private final UserRepository userRepository;
    private final ObjectProvider<FirebaseMessaging> firebaseMessagingProvider;

    @Transactional
    public void registerToken(Long userId, String token, String deviceId) {
        if (userId == null) {
            throw new EntityNotFoundException("사용자 정보를 확인할 수 없습니다.");
        }
        if (!StringUtils.hasText(token)) {
            throw new IllegalArgumentException("FCM 토큰을 입력하세요.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new EntityNotFoundException("사용자 정보를 찾을 수 없습니다."));

        FcmToken tokenByDevice = StringUtils.hasText(deviceId)
            ? fcmTokenRepository.findByUser_IdAndDeviceId(userId, deviceId).orElse(null)
            : null;

        if (tokenByDevice != null) {
            tokenByDevice.updateToken(token, deviceId);
            return;
        }

        FcmToken existingByToken = fcmTokenRepository.findByToken(token).orElse(null);
        if (existingByToken != null) {
            existingByToken.reassign(user, deviceId);
            existingByToken.updateToken(token, deviceId);
            return;
        }

        FcmToken newToken = FcmToken.builder()
                .user(user)
                .deviceId(deviceId)
                .token(token)
                .build();
        fcmTokenRepository.save(newToken);
    }

    @Transactional
    public void removeToken(Long userId, String token) {
        if (userId == null || !StringUtils.hasText(token)) {
            return;
        }
        fcmTokenRepository.deleteByUser_IdAndToken(userId, token);
    }

    @Async("fcmExecutor")
    @Transactional(readOnly = true)
    public void sendChatMessageNotification(ChatMessage message,
                                            Long chatRoomId,
                                            Collection<Long> targetUserIds) {
        if (!firebaseProperties.isEnabled()) {
            return;
        }
        if (targetUserIds == null || targetUserIds.isEmpty()) {
            return;
        }

        List<FcmToken> tokens = collectTokens(targetUserIds);
        if (tokens.isEmpty()) {
            return;
        }

        Notification notification = Notification.builder()
                .setTitle(resolveTitle(message))
                .setBody(resolveBody(message))
                .build();

        try {
            sendMessages(notification, buildChatData(message, chatRoomId), tokens);
        } catch (FirebaseMessagingException ex) {
            log.warn("FCM 메시지 전송에 실패했습니다. targetUserIds={}", targetUserIds, ex);
        }
    }

    @Async("fcmExecutor")
    @Transactional
    public void sendJointOrderRequestNotification(Long recipientUserId,
                                                  JointOrderRequestNotificationDto payload) {
        log.info("🔔 [FCM] 합동 주문 요청 알림 전송 시작 - requestId={}, recipient={}", 
                payload != null ? payload.requestId() : null, recipientUserId);
        
        if (!isNotificationAvailable(recipientUserId) || payload == null || payload.requestId() == null) {
            log.debug("FCM 전송 조건 미충족 - recipientUserId={}, payload={}", recipientUserId, payload);
            return;
        }

        List<FcmToken> tokens = collectTokens(List.of(recipientUserId));
        if (tokens.isEmpty()) {
            log.warn("⚠️ FCM 토큰 없음 - recipientUserId={}", recipientUserId);
            return;
        }

        String referenceKey = payload.requestId() + ":request";
        NotificationSendHistory history = reserveNotification(NotificationType.JOINT_ORDER_REQUEST, referenceKey, recipientUserId);
        if (history == null) {
            log.debug("중복 알림 방지 - requestId={}, recipient={}", payload.requestId(), recipientUserId);
            return;
        }

        Map<String, String> data = buildJointOrderRequestData(payload);
        Notification notification = Notification.builder()
                .setTitle("새 합동 주문 요청")
                .setBody(payload.requesterName() + "님이 합동 주문을 요청했습니다.")
                .build();

        try {
            log.info("📤 FCM 전송 중 - requestId={}, recipient={}, tokenCount={}", 
                    payload.requestId(), recipientUserId, tokens.size());
            sendMessages(notification, data, tokens);
            log.info("✅ FCM 전송 성공 - requestId={}, recipient={}", payload.requestId(), recipientUserId);
        } catch (FirebaseMessagingException ex) {
            releaseNotification(NotificationType.JOINT_ORDER_REQUEST, referenceKey, recipientUserId, history);
            log.warn("❌ 합동 주문 요청 푸시 전송 실패 - requestId={}, recipient={}, error={}", 
                    payload.requestId(), recipientUserId, ex.getMessage(), ex);
        }
    }

    @Async("fcmExecutor")
    @Transactional
    public void sendJointOrderStatusNotification(Long recipientUserId,
                                                 JointOrderStatusNotificationDto payload) {
        if (!isNotificationAvailable(recipientUserId) || payload == null || payload.requestId() == null) {
            return;
        }

        List<FcmToken> tokens = collectTokens(List.of(recipientUserId));
        if (tokens.isEmpty()) {
            return;
        }

        String referenceKey = payload.requestId() + ":status:" + payload.status();
        NotificationSendHistory history = reserveNotification(NotificationType.JOINT_ORDER_UPDATE, referenceKey, recipientUserId);
        if (history == null) {
            return;
        }

        Map<String, String> data = buildJointOrderStatusData(payload);
        Notification notification = Notification.builder()
                .setTitle("합동 주문 상태 변경")
                .setBody("요청 상태가 " + payload.status() + " 상태로 변경되었습니다.")
                .build();

        try {
            sendMessages(notification, data, tokens);
        } catch (FirebaseMessagingException ex) {
            releaseNotification(NotificationType.JOINT_ORDER_UPDATE, referenceKey, recipientUserId, history);
            log.warn("합동 주문 상태 푸시 전송 실패. requestId={}, recipient={}", payload.requestId(), recipientUserId, ex);
        }
    }

    @Async("fcmExecutor")
    @Transactional(readOnly = true)
    public void sendDeliveryStatusNotification(Long roomId,
                                                Collection<Long> targetUserIds,
                                                String status) {
        if (!firebaseProperties.isEnabled() || targetUserIds == null || targetUserIds.isEmpty()) {
            return;
        }
        List<FcmToken> tokens = collectTokens(targetUserIds);
        if (tokens.isEmpty()) {
            return;
        }

        String resolvedStatus = status != null ? status : "updated";
        String title = "배달 상태 변경";
        String body;
        switch (resolvedStatus) {
            case "started" -> body = "배달이 시작되었습니다. 수령을 준비하세요.";
            case "disputed" -> body = "정산 문제가 신고되었습니다. 앱에서 확인하세요.";
            case "reminder" -> body = "수령 확인을 완료해 주세요.";
            case "cancelled" -> body = "결제가 만료되어 환불이 진행되었습니다.";
            default -> body = "배달 상태가 업데이트되었습니다.";
        }

        Map<String, String> data = new HashMap<>();
        data.put("type", "delivery_status");
        data.put("roomId", roomId != null ? String.valueOf(roomId) : "");
        data.put("status", resolvedStatus);

        Notification notification = Notification.builder()
                .setTitle(title)
                .setBody(body)
                .build();
        try {
            sendMessages(notification, data, tokens);
        } catch (FirebaseMessagingException ex) {
            log.warn("배달 상태 푸시 전송 실패. roomId={}, status={}", roomId, resolvedStatus, ex);
        }
    }

    /**
     * 게시글 참여 알림 전송 (합동 주문과 별개)
     * 새 참여자가 게시글에 참여했을 때 방장에게 알림
     */
    @Async("fcmExecutor")
    @Transactional(readOnly = true)
    public void sendPostJoinNotification(Long hostUserId, Long postId, String participantName, String postTitle) {
        if (!firebaseProperties.isEnabled() || hostUserId == null) {
            return;
        }

        List<FcmToken> tokens = collectTokens(List.of(hostUserId));
        if (tokens.isEmpty()) {
            log.debug("게시글 참여 알림 전송 실패: FCM 토큰 없음 - hostUserId={}", hostUserId);
            return;
        }

        String title = "새 참여자";
        String body = participantName + "님이 \"" + postTitle + "\" 게시글에 참여했습니다.";

        Map<String, String> data = new HashMap<>();
        data.put("type", "post_join");
        data.put("postId", postId != null ? String.valueOf(postId) : "");
        data.put("participantName", Objects.toString(participantName, ""));
        data.put("postTitle", Objects.toString(postTitle, ""));

        Notification notification = Notification.builder()
                .setTitle(title)
                .setBody(body)
                .build();

        try {
            sendMessages(notification, data, tokens);
            log.info("📨 게시글 참여 알림 전송 성공 - postId={}, host={}, participant={}", postId, hostUserId, participantName);
        } catch (FirebaseMessagingException ex) {
            log.warn("게시글 참여 알림 전송 실패. postId={}, host={}", postId, hostUserId, ex);
        }
    }

    /**
     * 공동 장바구니 상태 변경 알림 전송
     * @param roomId 채팅방 ID
     * @param targetUserIds 알림 수신자 목록
     * @param eventType 이벤트 타입 (order_confirmed, all_paid, all_received, settlement_completed)
     * @param postTitle 게시글 제목 (선택)
     */
    @Async("fcmExecutor")
    @Transactional(readOnly = true)
    public void sendSharedCartStatusNotification(Long roomId,
                                                  Collection<Long> targetUserIds,
                                                  String eventType,
                                                  String postTitle) {
        if (!firebaseProperties.isEnabled() || targetUserIds == null || targetUserIds.isEmpty()) {
            return;
        }

        List<FcmToken> tokens = collectTokens(targetUserIds);
        if (tokens.isEmpty()) {
            log.debug("공동 장바구니 알림 전송 실패: FCM 토큰 없음 - roomId={}, eventType={}", roomId, eventType);
            return;
        }

        String title;
        String body;
        switch (eventType) {
            case "order_confirmed" -> {
                title = "주문 확정";
                body = "주문이 확정되었습니다. 결제를 진행해 주세요.";
            }
            case "all_paid" -> {
                title = "결제 완료";
                body = "모든 참여자가 결제를 완료했습니다. 배달을 시작해 주세요.";
            }
            case "all_received" -> {
                title = "수령 완료";
                body = "모든 참여자가 수령을 확인했습니다.";
            }
            case "settlement_completed" -> {
                title = "정산 완료";
                body = "정산이 완료되었습니다. 포인트가 정산되었습니다.";
            }
            default -> {
                title = "주문 상태 변경";
                body = "주문 상태가 업데이트되었습니다.";
            }
        }

        if (postTitle != null && !postTitle.isBlank()) {
            body = "[" + postTitle + "] " + body;
        }

        Map<String, String> data = new HashMap<>();
        data.put("type", "shared_cart_status");
        data.put("eventType", eventType);
        data.put("roomId", roomId != null ? String.valueOf(roomId) : "");

        Notification notification = Notification.builder()
                .setTitle(title)
                .setBody(body)
                .build();

        try {
            sendMessages(notification, data, tokens);
            log.info("📨 공동 장바구니 상태 알림 전송 성공 - roomId={}, eventType={}, recipients={}", 
                    roomId, eventType, targetUserIds.size());
        } catch (FirebaseMessagingException ex) {
            log.warn("공동 장바구니 상태 알림 전송 실패. roomId={}, eventType={}", roomId, eventType, ex);
        }
    }

    private String resolveTitle(ChatMessage message) {
        if (message.getSender() != null && StringUtils.hasText(message.getSender().getNickname())) {
            return message.getSender().getNickname();
        }
        return "새 메시지";
    }

    private String resolveBody(ChatMessage message) {
        if (!StringUtils.hasText(message.getMessageContent())) {
            return message.getMessageType().getDbValue();
        }
        return message.getMessageContent();
    }

    private Map<String, String> buildChatData(ChatMessage message, Long chatRoomId) {
        Map<String, String> data = new HashMap<>();
        data.put("type", "chat_message");
        data.put("roomId", String.valueOf(chatRoomId));
        data.put("messageId", String.valueOf(message.getId()));
        data.put("messageContent", Objects.toString(message.getMessageContent(), ""));
        data.put("messageType", message.getMessageType().getDbValue());
        data.put("senderId", message.getSender() != null ? String.valueOf(message.getSender().getId()) : "");
        data.put("senderNickname", message.getSender() != null ? Objects.toString(message.getSender().getNickname(), "") : "");
        return data;
    }

    private Map<String, String> buildJointOrderRequestData(JointOrderRequestNotificationDto payload) {
        Map<String, String> data = new HashMap<>();
        data.put("type", "joint_order_request");
        data.put("requestId", String.valueOf(payload.requestId()));
        data.put("postId", payload.postId() != null ? String.valueOf(payload.postId()) : "");
        data.put("requesterId", payload.requesterId() != null ? String.valueOf(payload.requesterId()) : "");
        data.put("requesterName", Objects.toString(payload.requesterName(), ""));
        data.put("storeName", Objects.toString(payload.storeName(), ""));
        data.put("deliveryPlace", Objects.toString(payload.deliveryPlace(), ""));
        data.put("orderTime", Objects.toString(payload.orderTime(), ""));
        return data;
    }

    private Map<String, String> buildJointOrderStatusData(JointOrderStatusNotificationDto payload) {
        Map<String, String> data = new HashMap<>();
        data.put("type", "joint_order_update");
        data.put("requestId", String.valueOf(payload.requestId()));
        data.put("postId", payload.postId() != null ? String.valueOf(payload.postId()) : "");
        data.put("status", Objects.toString(payload.status(), ""));
        data.put("chatRoomId", payload.chatRoomId() != null ? String.valueOf(payload.chatRoomId()) : "");
        data.put("storeName", Objects.toString(payload.storeName(), ""));
        data.put("deliveryPlace", Objects.toString(payload.deliveryPlace(), ""));
        return data;
    }

    private List<FcmToken> collectTokens(Collection<Long> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return List.of();
        }
        return fcmTokenRepository.findAllByUser_IdIn(userIds).stream()
                .filter(token -> StringUtils.hasText(token.getToken()))
                .collect(Collectors.toList());
    }

    private void sendMessages(Notification notification,
                              Map<String, String> data,
                              List<FcmToken> tokens) throws FirebaseMessagingException {
        FirebaseMessaging messaging = firebaseMessagingProvider.getIfAvailable();
        if (messaging == null) {
            log.debug("FirebaseMessaging 빈이 없어 푸시 전송을 건너뜁니다.");
            return;
        }
        if (tokens.isEmpty()) {
            return;
        }
        List<Message> requests = tokens.stream()
                .map(token -> {
                    Message.Builder builder = Message.builder().setToken(token.getToken());
                    if (notification != null) {
                        builder.setNotification(notification);
                    }
                    data.forEach(builder::putData);
                    return builder.build();
                })
                .toList();
        messaging.sendEach(requests);
    }

    private NotificationSendHistory reserveNotification(NotificationType type,
                                                        String referenceKey,
                                                        Long userId) {
        NotificationSendHistory history = NotificationSendHistory.of(type, referenceKey, userId);
        try {
            return notificationSendHistoryRepository.saveAndFlush(history);
        } catch (DataIntegrityViolationException ex) {
            log.debug("중복 푸시 요청이 감지되어 건너뜁니다. type={}, reference={}, userId={}", type, referenceKey, userId);
            return null;
        }
    }

    private void releaseNotification(NotificationType type,
                                     String referenceKey,
                                     Long userId,
                                     NotificationSendHistory history) {
        if (history == null) {
            return;
        }
        try {
            notificationSendHistoryRepository.delete(history);
        } catch (Exception ex) {
            log.warn("푸시 발송 실패 후 이력 정리 중 오류 발생. type={}, reference={}, userId={}", type, referenceKey, userId, ex);
        }
    }

    private boolean isNotificationAvailable(Long userId) {
        return firebaseProperties.isEnabled() && userId != null;
    }
}
