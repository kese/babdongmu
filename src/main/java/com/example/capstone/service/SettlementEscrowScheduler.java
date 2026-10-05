package com.example.capstone.service;

import com.example.capstone.domain.User;
import com.example.capstone.domain.cart.SharedCart;
import com.example.capstone.domain.chat.ChatRoom;
import com.example.capstone.domain.chat.ChatRoomParticipant;
import com.example.capstone.domain.chat.ChatRoomStatus;
import com.example.capstone.domain.settlement.DeliverySettlement;
import com.example.capstone.repository.ChatRoomParticipantRepository;
import com.example.capstone.repository.ChatRoomRepository;
import com.example.capstone.repository.DeliverySettlementRepository;
import com.example.capstone.repository.SharedCartRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

@Slf4j
@Component
@RequiredArgsConstructor
public class SettlementEscrowScheduler {

    private static final int READY_TO_START_TIMEOUT_MINUTES = 15;
    private static final int IN_PROGRESS_REMINDER_MINUTES = 60;

    private final ChatRoomRepository chatRoomRepository;
    private final SharedCartRepository sharedCartRepository;
    private final DeliverySettlementRepository deliverySettlementRepository;
    private final ChatRoomParticipantRepository chatRoomParticipantRepository;
    private final FcmService fcmService;

    @Scheduled(fixedDelayString = "PT5M")
    @Transactional
    public void cancelExpiredReadyToStartRooms() {
        LocalDateTime threshold = LocalDateTime.now().minusMinutes(READY_TO_START_TIMEOUT_MINUTES);
        List<ChatRoom> expiredRooms = chatRoomRepository.findByRoomStatusAndUpdatedAtBefore(ChatRoomStatus.ORDERING, threshold);
        for (ChatRoom room : expiredRooms) {
            try {
                cancelRoom(room);
            } catch (Exception ex) {
                log.warn("READY_TO_START 만료 처리 중 오류 발생. roomId={}", room.getId(), ex);
            }
        }
    }

    @Scheduled(fixedDelayString = "PT10M")
    @Transactional(readOnly = true)
    public void remindPendingReception() {
        LocalDateTime threshold = LocalDateTime.now().minusMinutes(IN_PROGRESS_REMINDER_MINUTES);
        List<ChatRoom> pendingRooms = chatRoomRepository.findByRoomStatusAndUpdatedAtBefore(ChatRoomStatus.DELIVERING, threshold);
        for (ChatRoom room : pendingRooms) {
            List<ChatRoomParticipant> pendingTargets = chatRoomParticipantRepository.findPendingReceptionTargets(room.getId());
            if (pendingTargets.isEmpty()) {
                continue;
            }
            List<Long> userIds = pendingTargets.stream()
                    .map(ChatRoomParticipant::getUser)
                    .filter(Objects::nonNull)
                    .map(User::getId)
                    .filter(Objects::nonNull)
                    .collect(Collectors.toList());
            if (userIds.isEmpty()) {
                continue;
            }
            try {
                fcmService.sendDeliveryStatusNotification(room.getId(), userIds, "reminder");
            } catch (Exception ex) {
                log.warn("수령 확인 독촉 푸시 전송 실패. roomId={}", room.getId(), ex);
            }
        }
    }

    private void cancelRoom(ChatRoom room) {
        SharedCart cart = sharedCartRepository.findTopByChatRoom_IdOrderByCreatedAtDesc(room.getId())
                .orElse(null);
        if (cart == null) {
            room.updateStatus(ChatRoomStatus.COMPLETED);
            room.clearEscrow();
            return;
        }

        List<DeliverySettlement> settlements = deliverySettlementRepository.findByCart_Id(cart.getId());
        settlements.forEach(settlement -> {
            User user = settlement.getUser();
            if (user != null) {
                user.increasePoint(settlement.getPointsCharged());
            }
        });
        if (!settlements.isEmpty()) {
            deliverySettlementRepository.deleteAll(settlements);
        }

        chatRoomParticipantRepository.findTargetsByRoomId(room.getId())
                .forEach(ChatRoomParticipant::unmarkAsTarget);
        room.clearEscrow();
        room.updateStatus(ChatRoomStatus.COMPLETED);

        List<Long> targetUserIds = chatRoomParticipantRepository.findUserIdsByChatRoomId(room.getId());
        if (!targetUserIds.isEmpty()) {
            try {
                fcmService.sendDeliveryStatusNotification(room.getId(), targetUserIds, "cancelled");
            } catch (Exception ex) {
                log.warn("READY_TO_START 만료 푸시 전송 실패. roomId={}", room.getId(), ex);
            }
        }
    }
}
