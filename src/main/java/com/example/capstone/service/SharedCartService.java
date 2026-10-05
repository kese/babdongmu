package com.example.capstone.service;

import com.example.capstone.config.WebSocketConfig;
import com.example.capstone.domain.User;
import com.example.capstone.domain.cart.SharedCart;
import com.example.capstone.domain.cart.SharedCartItem;
import com.example.capstone.domain.chat.ChatMessage;
import com.example.capstone.domain.chat.ChatRoom;
import com.example.capstone.domain.chat.ChatRoomParticipant;
import com.example.capstone.domain.chat.ChatRoomStatus;
import com.example.capstone.domain.chat.MessageType;
import com.example.capstone.domain.post.DeliveryDetail;
import com.example.capstone.domain.post.Post;
import com.example.capstone.domain.post.PostType;
import com.example.capstone.domain.settlement.DeliverySettlement;
import com.example.capstone.domain.settlement.SettlementRequest;
import com.example.capstone.domain.settlement.SettlementRequestStatus;
import com.example.capstone.dto.ApiEnvelope;
import com.example.capstone.dto.chat.ChatMessageResponseDto;
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
import com.example.capstone.exception.ForbiddenException;
import com.example.capstone.repository.ChatMessageRepository;
import com.example.capstone.repository.ChatRoomParticipantRepository;
import com.example.capstone.repository.ChatRoomRepository;
import com.example.capstone.repository.DeliverySettlementRepository;
import com.example.capstone.repository.SettlementRequestRepository;
import com.example.capstone.repository.SharedCartItemRepository;
import com.example.capstone.repository.SharedCartRepository;
import com.example.capstone.repository.UserRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class SharedCartService {

    private final SharedCartRepository sharedCartRepository;
    private final SharedCartItemRepository sharedCartItemRepository;
    private final ChatRoomParticipantRepository chatRoomParticipantRepository;
    private final ChatRoomRepository chatRoomRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final DeliverySettlementRepository deliverySettlementRepository;
    private final SettlementRequestRepository settlementRequestRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;
    private final SimpMessagingTemplate messagingTemplate;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> findRoomBasicInfo(Long userId, Long roomId) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        List<ChatRoomParticipant> targets = chatRoomParticipantRepository.findTargetsByRoomId(roomId);
        return ApiEnvelope.ok(ChatRoomBasicInfoResponseDto.from(chatRoom, targets));
    }

    @Transactional
    public ApiEnvelope<SharedCartResponseDto> activate(Long userId, Long roomId) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        User host = resolveHostOrThrow(chatRoom);
        validateHost(userId, host);

        Optional<SharedCart> activeCart = sharedCartRepository.findByChatRoom_IdAndActiveTrue(roomId);
        if (activeCart.isPresent()) {
            SharedCartResponseDto response = SharedCartResponseDto.from(activeCart.get());
            return ApiEnvelope.ok("이미 활성화된 장바구니가 있습니다.", response);
        }

        SharedCart cart = SharedCart.initialize(chatRoom, host);
        chatRoom.updateStatus(ChatRoomStatus.BEFORE_ORDER);
        SharedCart saved = sharedCartRepository.save(cart);
        SharedCartResponseDto response = SharedCartResponseDto.from(saved);

        publishAfterCommit(() -> publishSharedCartEvent(roomId, "activated", response));
        return ApiEnvelope.ok(response);
    }

    @Transactional(readOnly = true)
    public ApiEnvelope<SharedCartResponseDto> findCart(Long userId, Long roomId) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        User host = resolveHostOrThrow(chatRoom);

        return sharedCartRepository.findByChatRoom_IdAndActiveTrue(roomId)
                .map(SharedCartResponseDto::from)
                .map(ApiEnvelope::ok)
                .orElseGet(() -> sharedCartRepository.findTopByChatRoom_IdOrderByCreatedAtDesc(roomId)
                        .map(SharedCartResponseDto::from)
                        .map(ApiEnvelope::ok)
                        .orElseGet(() -> ApiEnvelope.ok(SharedCartResponseDto.empty(chatRoom.getId(), host.getId()))));
    }

    @Transactional
    public ApiEnvelope<SharedCartItemResponseDto> addItem(Long userId,
                                                          Long roomId,
                                                          SharedCartItemRequestDto request) {
        requireUser(userId);
        SharedCart cart = sharedCartRepository.findByChatRoom_IdAndActiveTrue(roomId)
                .orElseThrow(() -> new IllegalStateException("활성화된 장바구니가 없습니다."));
        ChatRoomParticipant participant = getParticipationOrThrow(roomId, userId);
        User user = participant.getUser();

        SharedCartItem item = SharedCartItem.builder()
                .cart(cart)
                .user(user)
                .name(request.name())
                .price(request.price())
                .build();
        SharedCartItem savedItem = sharedCartItemRepository.save(item);
        cart.getItems().add(savedItem);

        SharedCartResponseDto snapshot = SharedCartResponseDto.from(cart);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "updated", snapshot));
        return ApiEnvelope.ok(SharedCartItemResponseDto.from(savedItem));
    }

    @Transactional
    public ApiEnvelope<SharedCartItemResponseDto> updateItem(Long userId,
                                                             Long roomId,
                                                             Long itemId,
                                                             SharedCartItemRequestDto request) {
        requireUser(userId);
        SharedCartItem item = sharedCartItemRepository.findByIdAndCart_ChatRoom_Id(itemId, roomId)
                .orElseThrow(() -> new EntityNotFoundException("장바구니 항목을 찾을 수 없습니다."));

        SharedCart cart = item.getCart();
        if (!cart.isActive()) {
            throw new IllegalStateException("완료된 장바구니입니다.");
        }

        User owner = item.getUser();
        User host = resolveHostOrThrow(cart.getChatRoom());
        if (!owner.getId().equals(userId) && !host.getId().equals(userId)) {
            throw new ForbiddenException("항목 수정 권한이 없습니다.");
        }

        item.update(request.name(), request.price());
        SharedCartResponseDto snapshot = SharedCartResponseDto.from(cart);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "updated", snapshot));
        return ApiEnvelope.ok(SharedCartItemResponseDto.from(item));
    }

    @Transactional
    public void deleteItem(Long userId, Long roomId, Long itemId) {
        requireUser(userId);
        SharedCartItem item = sharedCartItemRepository.findByIdAndCart_ChatRoom_Id(itemId, roomId)
                .orElseThrow(() -> new EntityNotFoundException("장바구니 항목을 찾을 수 없습니다."));

        SharedCart cart = item.getCart();
        if (!cart.isActive()) {
            throw new IllegalStateException("완료된 장바구니입니다.");
        }

        User owner = item.getUser();
        User host = resolveHostOrThrow(cart.getChatRoom());
        if (!owner.getId().equals(userId) && !host.getId().equals(userId)) {
            throw new ForbiddenException("항목 삭제 권한이 없습니다.");
        }

        cart.getItems().remove(item);
        sharedCartItemRepository.delete(item);
        SharedCartResponseDto snapshot = SharedCartResponseDto.from(cart);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "updated", snapshot));
    }

    @Transactional
    public ApiEnvelope<SharedCartSummaryResponseDto> complete(Long userId, Long roomId) {
        requireUser(userId);
        SharedCart cart = sharedCartRepository.findByChatRoom_IdAndActiveTrue(roomId)
                .orElseThrow(() -> new IllegalStateException("활성화된 장바구니가 없습니다."));

        ChatRoom chatRoom = cart.getChatRoom();
        User host = resolveHostOrThrow(chatRoom);
        validateHost(userId, host);

        // 참여자별 메뉴 검증 추가
        validateParticipantsHaveItems(cart, roomId);

        cart.markCompleted(LocalDateTime.now());

        Integer deliveryFee = SharedCartSummaryResponseDto.resolveDeliveryFee(chatRoom.getPost());
        Integer deliveryFeePerPerson = calculateDeliveryFeePerPerson(deliveryFee, collectParticipantIds(chatRoom, host));
        SharedCartSummaryResponseDto summary = SharedCartSummaryResponseDto.pending(cart, chatRoom, deliveryFee, deliveryFeePerPerson);
        ChatMessage receiptMessage = ChatMessage.builder()
                .chatRoom(chatRoom)
                .sender(host)
                .messageContent("주문이 완료되었습니다. 정산을 진행해 주세요.")
                .messageType(MessageType.RECEIPT)
                .build();

        try {
            receiptMessage.attachCartSummary(objectMapper.writeValueAsString(summary));
        } catch (JsonProcessingException e) {
            log.warn("영수증 요약 직렬화 실패. cartId={}", cart.getId(), e);
        }

        ChatMessage savedMessage = chatMessageRepository.save(receiptMessage);
        ChatMessageResponseDto messagePayload = ChatMessageResponseDto.of(savedMessage, host.getId());
        List<Long> recipientIds = chatRoomParticipantRepository.findUserIdsByChatRoomId(roomId).stream()
                .filter(id -> !id.equals(host.getId()))
                .toList();

        publishAfterCommit(() -> publishSharedCartEvent(roomId, "completed", summary));
        publishAfterCommit(() -> publishToChatTopic(roomId, messagePayload));
        if (!recipientIds.isEmpty()) {
            publishAfterCommit(() -> sendFcmNotification(savedMessage, roomId, recipientIds));
        }

        return ApiEnvelope.ok(summary);
    }

    /**
     * 모든 참여자가 최소 1개 이상의 메뉴를 담았는지 검증
     */
    private void validateParticipantsHaveItems(SharedCart cart, Long roomId) {
        // 채팅방 참여자 목록 조회
        List<ChatRoomParticipant> participants = chatRoomParticipantRepository.findByChatRoom_Id(roomId);
        
        // 참여자별 장바구니 아이템 그룹화
        Map<Long, List<SharedCartItem>> itemsByUser = cart.getItems().stream()
                .collect(Collectors.groupingBy(item -> item.getUser().getId()));
        
        // 메뉴를 담지 않은 참여자 확인
        List<String> missingParticipants = participants.stream()
                .filter(p -> p.getUser() != null) // null 사용자 제외
                .filter(p -> !itemsByUser.containsKey(p.getUser().getId()) || 
                            itemsByUser.get(p.getUser().getId()).isEmpty())
                .map(p -> p.getUser().getNickname())
                .collect(Collectors.toList());
        
        if (!missingParticipants.isEmpty()) {
            throw new IllegalStateException(
                String.format("모든 참여자가 최소 1개 이상의 메뉴를 담아야 합니다. 메뉴를 담지 않은 참여자: %s", 
                String.join(", ", missingParticipants))
            );
        }
    }

    @Transactional
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> finalizeOrder(Long userId,
                                                                   Long roomId,
                                                                   FinalizeOrderRequestDto request) {
        requireUser(userId);
        if (request == null) {
            throw new IllegalArgumentException("요청 본문이 필요합니다.");
        }
        if (request.targetParticipantIds() == null || request.targetParticipantIds().isEmpty()) {
            throw new IllegalArgumentException("정산 대상자가 필요합니다.");
        }

        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        User host = resolveHostOrThrow(chatRoom);
        validateHost(userId, host);

        if (chatRoom.getRoomStatus() == ChatRoomStatus.DISPUTED || chatRoom.getRoomStatus() == ChatRoomStatus.COMPLETED) {
            throw new IllegalStateException("분쟁 중이거나 완료된 방에서는 주문을 확정할 수 없습니다.");
        }

        SharedCart cart = sharedCartRepository.findByIdAndChatRoom_Id(request.cartId(), roomId)
                .orElseThrow(() -> new EntityNotFoundException("장바구니를 찾을 수 없습니다."));
        if (cart.isActive()) {
            throw new IllegalStateException("주문 완료 후에만 확정할 수 있습니다.");
        }

        List<DeliverySettlement> existingSettlements = deliverySettlementRepository.findByCart_Id(cart.getId());
        if (!existingSettlements.isEmpty()) {
            existingSettlements.forEach(settlement -> {
                User targetUser = settlement.getUser();
                if (targetUser != null) {
                    targetUser.increasePoint(settlement.getPointsCharged());
                }
            });
            deliverySettlementRepository.deleteAll(existingSettlements);
        }

        List<Long> participantIds = chatRoomParticipantRepository.findUserIdsByChatRoomId(roomId);
        
        // 장바구니에 메뉴를 추가한 모든 참여자를 자동으로 포함
        Set<Long> cartParticipantIds = cart.getItems().stream()
                .filter(item -> item.getUser() != null)
                .map(item -> item.getUser().getId())
                .collect(Collectors.toSet());
        
        // 클라이언트가 보낸 targetParticipantIds와 장바구니 참여자를 합침
        LinkedHashSet<Long> targetIds = new LinkedHashSet<>();
        if (request.targetParticipantIds() != null) {
            targetIds.addAll(request.targetParticipantIds().stream()
                    .filter(Objects::nonNull)
                    .collect(Collectors.toList()));
        }
        // 장바구니에 메뉴가 있는 모든 참여자를 target에 포함
        targetIds.addAll(cartParticipantIds);
        
        if (!participantIds.containsAll(targetIds)) {
            throw new ForbiddenException("채팅방 참여자만 선택할 수 있습니다.");
        }

        if (targetIds.isEmpty()) {
            throw new IllegalArgumentException("정산 대상자가 필요합니다.");
        }

        LocalDateTime now = LocalDateTime.now();
        List<ChatRoomParticipant> participants = chatRoomParticipantRepository.findByChatRoom_Id(roomId);
        participants.forEach(p -> {
            Long pid = p.getUser() != null ? p.getUser().getId() : null;
            if (pid != null && targetIds.contains(pid)) {
                p.markAsTarget(now);
            } else {
                p.unmarkAsTarget();
            }
        });

        Integer deliveryFee = SharedCartSummaryResponseDto.resolveDeliveryFee(chatRoom.getPost());
        LinkedHashSet<Long> targetSet = new LinkedHashSet<>(targetIds);
        Integer deliveryFeePerPerson = calculateDeliveryFeePerPerson(deliveryFee, targetSet);
        SharedCartSummaryResponseDto summary = SharedCartSummaryResponseDto.pending(cart, chatRoom, deliveryFee, deliveryFeePerPerson);
        int totalPrice = summary.totalPrice();
        Integer expected = request.expectedTotalPoint();
        if (expected != null && !expected.equals(totalPrice)) {
            throw new IllegalArgumentException("요청된 총 정산 금액이 장바구니 합계와 일치하지 않습니다.");
        }

        chatRoom.updateEscrowTotal(0);
        chatRoom.lockEscrow(totalPrice, now);
        chatRoom.updateStatus(ChatRoomStatus.ORDERING);

        List<ChatRoomParticipant> targets = chatRoomParticipantRepository.findTargetsByRoomId(roomId);
        ChatRoomBasicInfoResponseDto response = ChatRoomBasicInfoResponseDto.from(chatRoom, targets);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "finalized-order", response));
        
        // FCM 알림: 주문 확정 알림 전송 (방장 제외 모든 참여자에게)
        String postTitle = chatRoom.getPost() != null ? chatRoom.getPost().getTitle() : null;
        List<Long> recipientIds = targetIds.stream()
                .filter(id -> !id.equals(host.getId()))
                .toList();
        if (!recipientIds.isEmpty()) {
            publishAfterCommit(() -> fcmService.sendSharedCartStatusNotification(roomId, recipientIds, "order_confirmed", postTitle));
        }
        
        return ApiEnvelope.ok(response);
    }

    @Transactional
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> startDelivery(Long userId, Long roomId) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        User host = resolveHostOrThrow(chatRoom);
        validateHost(userId, host);

        if (chatRoom.getRoomStatus() != ChatRoomStatus.ORDERING) {
            throw new IllegalStateException("결제 완료 후에만 배달을 시작할 수 있습니다.");
        }
        if (chatRoomParticipantRepository.existsReportedIssue(roomId)) {
            throw new IllegalStateException("분쟁 상태에서는 배달을 시작할 수 없습니다.");
        }

        chatRoom.updateStatus(ChatRoomStatus.DELIVERING);
        List<ChatRoomParticipant> targets = chatRoomParticipantRepository.findTargetsByRoomId(roomId);
        targets.forEach(ChatRoomParticipant::resetDeliveryGuideAcceptance);
        ChatRoomBasicInfoResponseDto response = ChatRoomBasicInfoResponseDto.from(chatRoom, targets);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "delivery-started", response));
        publishAfterCommit(() -> notifyDeliveryStatus(roomId, targets, "started"));
        return ApiEnvelope.ok(response);
    }

    @Transactional
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> confirmReception(Long userId, Long roomId) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        if (!Boolean.TRUE.equals(participation.getTarget())) {
            throw new ForbiddenException("확정 대상만 수령 확인이 가능합니다.");
        }

        if (chatRoom.getRoomStatus() != ChatRoomStatus.DELIVERING) {
            throw new IllegalStateException("배달 진행 중에만 수령 확인을 할 수 있습니다.");
        }

        if (!Boolean.TRUE.equals(participation.getConfirmedReception())) {
            participation.confirmReception();
        }

        boolean pending = chatRoomParticipantRepository.countTargetsPendingReception(roomId) > 0;
        boolean hasIssue = chatRoomParticipantRepository.existsReportedIssue(roomId);
        SharedCart cart = resolveCartForSettlement(chatRoom, null);
        if (!pending && !hasIssue) {
            finalizeAfterReception(cart, chatRoom, LocalDateTime.now());
        }

        List<ChatRoomParticipant> targets = chatRoomParticipantRepository.findTargetsByRoomId(roomId);
        ChatRoomBasicInfoResponseDto response = ChatRoomBasicInfoResponseDto.from(chatRoom, targets);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "reception-updated", response));
        return ApiEnvelope.ok(response);
    }

    @Transactional
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> reportIssue(Long userId, Long roomId) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        if (!Boolean.TRUE.equals(participation.getTarget())) {
            throw new ForbiddenException("확정 대상만 문제를 신고할 수 있습니다.");
        }

        participation.reportIssue();
        chatRoom.updateStatus(ChatRoomStatus.DISPUTED);

        List<ChatRoomParticipant> targets = chatRoomParticipantRepository.findTargetsByRoomId(roomId);
        ChatRoomBasicInfoResponseDto response = ChatRoomBasicInfoResponseDto.from(chatRoom, targets);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "disputed", response));
        publishAfterCommit(() -> notifyDeliveryStatus(roomId, targets, "disputed"));
        return ApiEnvelope.ok(response);
    }

    @Transactional
    public ApiEnvelope<ChatRoomBasicInfoResponseDto> acceptDeliveryGuide(Long userId, Long roomId) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();

        if (chatRoom.getRoomStatus() != ChatRoomStatus.DELIVERING) {
            throw new IllegalStateException("배달 진행 중에만 안전 가이드를 동의할 수 있습니다.");
        }

        if (!Boolean.TRUE.equals(participation.getHasAcceptedDeliveryGuide())) {
            participation.acceptDeliveryGuide();
        }

        List<ChatRoomParticipant> targets = chatRoomParticipantRepository.findTargetsByRoomId(roomId);
        ChatRoomBasicInfoResponseDto response = ChatRoomBasicInfoResponseDto.from(chatRoom, targets);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "guide-accepted", response));
        return ApiEnvelope.ok(response);
    }

    @Transactional
    public ApiEnvelope<SettlementTransferResponseDto> transferSettlement(Long userId,
                                                                         Long roomId,
                                                                         SettlementTransferRequestDto request) {
        requireUser(userId);
        if (request == null || request.transfers() == null || request.transfers().isEmpty()) {
            throw new IllegalArgumentException("정산 대상이 비어 있습니다.");
        }

        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        User host = resolveHostOrThrow(chatRoom);
        validateHost(userId, host);

        ChatRoomStatus currentStatus = chatRoom.getRoomStatus();
        if (currentStatus == ChatRoomStatus.DISPUTED || currentStatus == ChatRoomStatus.COMPLETED || currentStatus == ChatRoomStatus.COMPLETED) {
            throw new IllegalStateException("현재 상태에서는 결제를 진행할 수 없습니다.");
        }

        if (chatRoom.getRoomStatus() != ChatRoomStatus.ORDERING) {
            throw new IllegalStateException("주문 확정 후 결제를 진행할 수 있습니다.");
        }

        SharedCart cart = resolveCartForSettlement(chatRoom, request.cartId());

        List<ChatRoomParticipant> targetParticipants = chatRoomParticipantRepository.findTargetsByRoomId(roomId);
        if (targetParticipants.isEmpty()) {
            throw new IllegalStateException("주문 확정 대상이 없습니다.");
        }

        Set<Long> targetIds = targetParticipants.stream()
                .map(ChatRoomParticipant::getUser)
                .filter(Objects::nonNull)
                .map(User::getId)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        Set<Long> requestedUserIds = request.transfers().stream()
                .map(SettlementTransferRequestDto.TransferItem::userId)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        if (requestedUserIds.size() != request.transfers().size()) {
            throw new IllegalArgumentException("정산 대상에 중복된 사용자가 포함되어 있습니다.");
        }

        if (!targetIds.containsAll(requestedUserIds)) {
            throw new ForbiddenException("확정된 참여자만 결제할 수 있습니다.");
        }

        Map<Long, User> participants = userRepository.findAllById(requestedUserIds).stream()
                .collect(Collectors.toMap(User::getId, user -> user));

        if (participants.size() != requestedUserIds.size()) {
            throw new EntityNotFoundException("정산 대상 사용자를 찾을 수 없습니다.");
        }

        boolean hasExplicitDeliveryShare = request.transfers().stream()
                .anyMatch(item -> item.deliveryFeeShare() != null);

        BigDecimal originalDeliveryFeeBaseline = null;
        if (hasExplicitDeliveryShare) {
            originalDeliveryFeeBaseline = resolveOriginalDeliveryFeeForPost(chatRoom.getPost());
            if (originalDeliveryFeeBaseline == null) {
                long totalShare = request.transfers().stream()
                        .map(item -> Optional.ofNullable(item.deliveryFeeShare()).orElse(0))
                        .mapToLong(Integer::longValue)
                        .sum();
                originalDeliveryFeeBaseline = BigDecimal.valueOf(totalShare);
            }
        }

        List<DeliverySettlement> existingSettlements = deliverySettlementRepository.findByCart_Id(cart.getId());
        if (!existingSettlements.isEmpty()) {
            existingSettlements.forEach(settlement -> {
                if (requestedUserIds.contains(settlement.getUser() != null ? settlement.getUser().getId() : null)) {
                    User target = settlement.getUser();
                    if (target != null) {
                        target.increasePoint(settlement.getPointsCharged());
                    }
                }
            });
            List<DeliverySettlement> toDelete = existingSettlements.stream()
                    .filter(settlement -> requestedUserIds.contains(settlement.getUser() != null ? settlement.getUser().getId() : null))
                    .toList();
            if (!toDelete.isEmpty()) {
                deliverySettlementRepository.deleteAll(toDelete);
            }
        }

        int participantCount = targetIds.size();
        LocalDateTime settledAt = LocalDateTime.now();

        List<DeliverySettlement> newSettlements = new ArrayList<>();
        List<SettlementTransferResponseDto.TransferResult> results = new ArrayList<>();

        for (SettlementTransferRequestDto.TransferItem item : request.transfers()) {
            User target = participants.get(item.userId());
            int amount = item.amount();
            if (amount < 0) {
                throw new IllegalArgumentException("정산 금액은 0 이상이어야 합니다.");
            }

            boolean hasDeliveryShare = item.deliveryFeeShare() != null;
            if (hasExplicitDeliveryShare && !hasDeliveryShare) {
                throw new IllegalArgumentException("deliveryFeeShare 값을 모든 정산 항목에 포함해 주세요.");
            }

            int deliveryShare = hasDeliveryShare ? item.deliveryFeeShare() : amount;
            if (hasDeliveryShare && deliveryShare > amount) {
                throw new IllegalArgumentException("배달비 분담 금액은 총 정산 금액을 초과할 수 없습니다.");
            }

            BigDecimal paidDeliveryFee = BigDecimal.valueOf(deliveryShare);
            BigDecimal originalDeliveryFee = hasDeliveryShare
                    ? (originalDeliveryFeeBaseline != null ? originalDeliveryFeeBaseline : paidDeliveryFee)
                    : BigDecimal.valueOf(amount);
            BigDecimal savedDeliveryFee = originalDeliveryFee.subtract(paidDeliveryFee);
            if (savedDeliveryFee.signum() < 0) {
                savedDeliveryFee = BigDecimal.ZERO;
            }
            target.decreasePoint(amount);

            DeliverySettlement settlement = DeliverySettlement.of(
                    target,
                    chatRoom.getPost(),
                    cart,
                    participantCount,
                    originalDeliveryFee,
                    paidDeliveryFee,
                    savedDeliveryFee,
                    amount,
                    settledAt
            );
            newSettlements.add(settlement);
            results.add(new SettlementTransferResponseDto.TransferResult(
                    target.getId(),
                    target.getNickname(),
                    amount,
                    target.getPointOrDefault()
            ));
        }

        deliverySettlementRepository.saveAll(newSettlements);

        List<DeliverySettlement> currentSettlements = deliverySettlementRepository.findByCart_Id(cart.getId());
        int escrowTotal = currentSettlements.stream()
                .mapToInt(DeliverySettlement::getPointsCharged)
                .sum();
        chatRoom.updateEscrowTotal(escrowTotal);

        Set<Long> paidUserIds = currentSettlements.stream()
                .map(DeliverySettlement::getUser)
                .filter(Objects::nonNull)
                .map(User::getId)
                .collect(Collectors.toSet());
        boolean readyToStart = escrowTotal >= chatRoom.getEscrowTargetPoint() && paidUserIds.containsAll(targetIds);
        if (readyToStart) {
            chatRoom.updateStatus(ChatRoomStatus.ORDERING);
            
            // FCM 알림: 모든 참여자 결제 완료 알림 (방장에게만)
            String postTitle = chatRoom.getPost() != null ? chatRoom.getPost().getTitle() : null;
            publishAfterCommit(() -> fcmService.sendSharedCartStatusNotification(roomId, List.of(host.getId()), "all_paid", postTitle));
        } else {
            chatRoom.updateStatus(ChatRoomStatus.ORDERING);
        }

        SettlementTransferResponseDto.HostResult hostResult = new SettlementTransferResponseDto.HostResult(
            host.getId(),
            host.getNickname(),
            0,
            host.getPointOrDefault()
        );

        SettlementTransferResponseDto.EscrowInfo escrowInfo = new SettlementTransferResponseDto.EscrowInfo(
                chatRoom.getEscrowTargetPoint(),
                chatRoom.getEscrowTotalPoint(),
                readyToStart
        );

        SettlementTransferResponseDto response = new SettlementTransferResponseDto(
            cart.getId(),
            roomId,
            settledAt,
            results,
            hostResult,
            escrowInfo
        );

        publishAfterCommit(() -> publishSharedCartEvent(roomId, "settlement", response));
        return ApiEnvelope.ok(response);
    }

    @Transactional
    public ApiEnvelope<SettlementRequestResponseDto> createSettlementRequest(Long userId,
                                                                             Long roomId,
                                                                             SettlementRequestCreateRequestDto request) {
        requireUser(userId);
        if (request == null) {
            throw new IllegalArgumentException("요청 본문이 필요합니다.");
        }

        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        SharedCart cart = resolveCartForSettlement(chatRoom, request.cartId());
        validateCartParticipant(cart, participation);

        User requester = Optional.ofNullable(participation.getUser())
                .orElseThrow(() -> new EntityNotFoundException("요청자 정보를 찾을 수 없습니다."));

        if (settlementRequestRepository.existsByCart_IdAndRequester_IdAndStatus(
                cart.getId(), requester.getId(), SettlementRequestStatus.PENDING)) {
            throw new IllegalStateException("이미 진행 중인 송금 요청이 있습니다.");
        }

        int amount = Optional.ofNullable(request.amount()).orElseThrow(() ->
                new IllegalArgumentException("정산 금액은 필수입니다."));
        if (amount < 0) {
            throw new IllegalArgumentException("정산 금액은 0 이상이어야 합니다.");
        }

        Integer deliveryShare = request.deliveryFeeShare();
        if (deliveryShare != null && deliveryShare < 0) {
            throw new IllegalArgumentException("배달비 분담 금액은 0 이상이어야 합니다.");
        }
        if (deliveryShare != null && deliveryShare > amount) {
            throw new IllegalArgumentException("배달비 분담 금액은 총 정산 금액을 초과할 수 없습니다.");
        }

        SettlementRequest pending = SettlementRequest.builder()
                .amount(amount)
                .deliveryFeeShare(deliveryShare)
                .memo(sanitizeMemo(request.memo()))
                .status(SettlementRequestStatus.PENDING)
                .build();
        pending.assignCart(cart);
        pending.assignRequester(requester);

        SettlementRequest saved = settlementRequestRepository.save(pending);
        SettlementRequestResponseDto response = SettlementRequestResponseDto.from(saved);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "settlement-requested", response));
        return ApiEnvelope.ok(response);
    }

    @Transactional(readOnly = true)
    public ApiEnvelope<SettlementRequestListResponseDto> getSettlementRequests(Long userId, Long roomId) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);

        SharedCart cart = sharedCartRepository.findByChatRoom_IdAndActiveTrue(roomId)
                .or(() -> sharedCartRepository.findTopByChatRoom_IdOrderByCreatedAtDesc(roomId))
                .orElseThrow(() -> new EntityNotFoundException("정산 대상 장바구니가 없습니다."));

        List<SettlementRequestResponseDto> responses = settlementRequestRepository
                .findByCart_IdOrderByRequestedAtAsc(cart.getId())
                .stream()
                .map(SettlementRequestResponseDto::from)
                .toList();

        return ApiEnvelope.ok(SettlementRequestListResponseDto.of(responses));
    }

    @Transactional
    public ApiEnvelope<SettlementRequestResponseDto> approveSettlementRequest(Long userId,
                                                                              Long roomId,
                                                                              Long requestId,
                                                                              SettlementRequestDecisionRequestDto decision) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        User host = resolveHostOrThrow(chatRoom);
        validateHost(userId, host);

        SettlementRequest settlementRequest = settlementRequestRepository
                .findByIdAndCart_ChatRoom_Id(requestId, roomId)
                .orElseThrow(() -> new EntityNotFoundException("송금 요청을 찾을 수 없습니다."));

        if (settlementRequest.getStatus() != SettlementRequestStatus.PENDING) {
            throw new IllegalStateException("이미 처리된 요청입니다.");
        }

        String decisionMemo = sanitizeMemo(decision != null ? decision.memo() : null);
        settlementRequest.approve(host, decisionMemo);
        SettlementTransferResponseDto transfer = applyApprovedSettlement(settlementRequest, host);
        SettlementRequest saved = settlementRequestRepository.save(settlementRequest);

        SettlementRequestResponseDto response = SettlementRequestResponseDto.from(saved);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "settlement-request-approved", response));
        if (transfer != null) {
            publishAfterCommit(() -> publishSharedCartEvent(roomId, "settlement", transfer));
        }
        return ApiEnvelope.ok(response);
    }

    @Transactional
    public ApiEnvelope<SettlementRequestResponseDto> rejectSettlementRequest(Long userId,
                                                                             Long roomId,
                                                                             Long requestId,
                                                                             SettlementRequestDecisionRequestDto decision) {
        requireUser(userId);
        ChatRoomParticipant participation = getParticipationOrThrow(roomId, userId);
        ChatRoom chatRoom = participation.getChatRoom();
        User host = resolveHostOrThrow(chatRoom);

        SettlementRequest settlementRequest = settlementRequestRepository
                .findByIdAndCart_ChatRoom_Id(requestId, roomId)
                .orElseThrow(() -> new EntityNotFoundException("송금 요청을 찾을 수 없습니다."));

        if (settlementRequest.getStatus() != SettlementRequestStatus.PENDING) {
            throw new IllegalStateException("이미 처리된 요청입니다.");
        }

        boolean isHost = host.getId().equals(userId);
        Long requesterId = settlementRequest.getRequester() != null ? settlementRequest.getRequester().getId() : null;
        boolean isRequester = requesterId != null && requesterId.equals(userId);
        if (!isHost && !isRequester) {
            throw new ForbiddenException("거절 권한이 없습니다.");
        }

        String decisionMemo = sanitizeMemo(decision != null ? decision.memo() : null);
        User processor = isHost ? host : settlementRequest.getRequester();
        settlementRequest.reject(processor, decisionMemo);
        SettlementRequest saved = settlementRequestRepository.save(settlementRequest);

        SettlementRequestResponseDto response = SettlementRequestResponseDto.from(saved);
        publishAfterCommit(() -> publishSharedCartEvent(roomId, "settlement-request-rejected", response));
        return ApiEnvelope.ok(response);
    }

    private void sendFcmNotification(ChatMessage message, Long roomId, List<Long> recipientIds) {
        try {
            fcmService.sendChatMessageNotification(message, roomId, recipientIds);
        } catch (Exception ex) {
            log.warn("영수증 채팅 FCM 전송 실패. roomId={}, messageId={}", roomId, message.getId(), ex);
        }
    }

    private void publishToChatTopic(Long roomId, ChatMessageResponseDto payload) {
        try {
            messagingTemplate.convertAndSend(WebSocketConfig.CHAT_TOPIC_PREFIX + "/chat.rooms." + roomId, payload);
        } catch (Exception ex) {
            log.warn("채팅 메시지 브로드캐스트 실패. roomId={}", roomId, ex);
        }
    }

    private void publishSharedCartEvent(Long roomId, String event, Object payload) {
        String destination = WebSocketConfig.CHAT_TOPIC_PREFIX + "/shared-cart.rooms." + roomId + "/" + event;
        try {
            messagingTemplate.convertAndSend(destination, payload);
        } catch (Exception ex) {
            log.warn("공용 장바구니 이벤트 전송 실패. roomId={}, event={}", roomId, event, ex);
        }
    }

    private void notifyDeliveryStatus(Long roomId, List<ChatRoomParticipant> targets, String status) {
        if (targets == null || targets.isEmpty()) {
            return;
        }
        List<Long> targetUserIds = targets.stream()
                .map(ChatRoomParticipant::getUser)
                .filter(Objects::nonNull)
                .map(User::getId)
                .filter(Objects::nonNull)
                .toList();
        if (targetUserIds.isEmpty()) {
            return;
        }
        try {
            fcmService.sendDeliveryStatusNotification(roomId, targetUserIds, status);
        } catch (Exception ex) {
            log.warn("배달 상태 푸시 전송 실패. roomId={}, status={}", roomId, status, ex);
        }
    }

    private void finalizeAfterReception(SharedCart cart, ChatRoom chatRoom, LocalDateTime finalizedAt) {
        if (cart == null || chatRoom == null || chatRoom.getId() == null) {
            return;
        }
        if (chatRoom.getRoomStatus() == ChatRoomStatus.COMPLETED || chatRoom.getRoomStatus() == ChatRoomStatus.DISPUTED) {
            return;
        }
        Long roomId = chatRoom.getId();
        if (chatRoomParticipantRepository.countTargetsPendingReception(roomId) > 0) {
            return;
        }
        if (chatRoomParticipantRepository.existsReportedIssue(roomId)) {
            return;
        }

        List<DeliverySettlement> settlements = deliverySettlementRepository.findByCart_Id(cart.getId());
        if (settlements.isEmpty()) {
            return;
        }

        boolean hasPendingRequests = !settlementRequestRepository
                .findByCart_IdAndStatus(cart.getId(), SettlementRequestStatus.PENDING)
                .isEmpty();
        if (hasPendingRequests) {
            return;
        }

        int escrowTotal = settlements.stream()
                .mapToInt(DeliverySettlement::getPointsCharged)
                .sum();

        User host = cart.getHost();
        Long hostId = host != null ? host.getId() : null;
        if (host != null && escrowTotal > 0) {
            host.increasePoint(escrowTotal);
        }
        chatRoom.clearEscrow();
        chatRoom.updateStatus(ChatRoomStatus.COMPLETED);

        Integer deliveryFee = SharedCartSummaryResponseDto.resolveDeliveryFee(chatRoom.getPost());
        LinkedHashSet<Long> targetIds = chatRoomParticipantRepository.findTargetsByRoomId(roomId).stream()
                .map(ChatRoomParticipant::getUser)
                .filter(Objects::nonNull)
                .map(User::getId)
                .collect(Collectors.toCollection(LinkedHashSet::new));
        Integer deliveryFeePerPerson = calculateDeliveryFeePerPerson(deliveryFee, targetIds);
        LocalDateTime finalizedTime = finalizedAt != null ? finalizedAt : LocalDateTime.now();
        SharedCartSummaryResponseDto summary = SharedCartSummaryResponseDto.finalized(cart, chatRoom, deliveryFee, deliveryFeePerPerson, finalizedTime);

        ChatMessage receiptMessage = ChatMessage.builder()
                .chatRoom(chatRoom)
                .sender(host)
                .messageContent("정산이 완료되었습니다.")
                .messageType(MessageType.RECEIPT)
                .build();

        try {
            receiptMessage.attachCartSummary(objectMapper.writeValueAsString(summary));
        } catch (JsonProcessingException e) {
            log.warn("최종 영수증 요약 직렬화 실패. cartId={}", cart.getId(), e);
        }

        ChatMessage savedMessage = chatMessageRepository.save(receiptMessage);
        ChatMessageResponseDto messagePayload = ChatMessageResponseDto.of(savedMessage, hostId);
        List<Long> recipientIds = chatRoomParticipantRepository.findUserIdsByChatRoomId(roomId).stream()
                .filter(id -> !Objects.equals(id, hostId))
                .toList();

        publishAfterCommit(() -> publishSharedCartEvent(roomId, "completed", summary));
        publishAfterCommit(() -> publishToChatTopic(roomId, messagePayload));
        if (!recipientIds.isEmpty()) {
            publishAfterCommit(() -> sendFcmNotification(savedMessage, roomId, recipientIds));
        }
        
        // FCM 알림: 모든 참여자 수령 확인 + 정산 완료 알림 (모든 참여자에게)
        String postTitle = chatRoom.getPost() != null ? chatRoom.getPost().getTitle() : null;
        List<Long> allParticipantIds = chatRoomParticipantRepository.findUserIdsByChatRoomId(roomId);
        if (!allParticipantIds.isEmpty()) {
            publishAfterCommit(() -> fcmService.sendSharedCartStatusNotification(roomId, allParticipantIds, "all_received", postTitle));
            publishAfterCommit(() -> fcmService.sendSharedCartStatusNotification(roomId, allParticipantIds, "settlement_completed", postTitle));
        }
    }

    private SettlementTransferResponseDto applyApprovedSettlement(SettlementRequest request, User host) {
        SharedCart cart = request.getCart();
        if (cart == null || cart.getId() == null || cart.getChatRoom() == null) {
            return null;
        }

        ChatRoom chatRoom = cart.getChatRoom();
        User requester = request.getRequester();
        if (requester == null || requester.getId() == null) {
            throw new EntityNotFoundException("정산 대상 사용자를 찾을 수 없습니다.");
        }

        List<ChatRoomParticipant> targetParticipants = chatRoomParticipantRepository.findTargetsByRoomId(chatRoom.getId());
        Set<Long> targetIds = targetParticipants.stream()
                .map(ChatRoomParticipant::getUser)
                .filter(Objects::nonNull)
                .map(User::getId)
                .collect(Collectors.toCollection(LinkedHashSet::new));
        if (!targetIds.contains(requester.getId())) {
            throw new ForbiddenException("확정된 참여자만 정산할 수 있습니다.");
        }

        List<DeliverySettlement> existingSettlements = deliverySettlementRepository
                .findByCart_IdAndUser_Id(cart.getId(), requester.getId());
        if (!existingSettlements.isEmpty()) {
            existingSettlements.forEach(settlement -> requester.increasePoint(settlement.getPointsCharged()));
            deliverySettlementRepository.deleteAll(existingSettlements);
        }

        int amount = Optional.ofNullable(request.getAmount()).orElse(0);
        LocalDateTime processedAt = request.getProcessedAt() != null ? request.getProcessedAt() : LocalDateTime.now();
        List<SettlementTransferResponseDto.TransferResult> results;
        if (amount > 0) {
            requester.decreasePoint(amount);

            BigDecimal paidFee = BigDecimal.valueOf(Optional.ofNullable(request.getDeliveryFeeShare()).orElse(amount));
            BigDecimal originalFee = resolveOriginalDeliveryFeeForPost(chatRoom.getPost());
            if (originalFee == null) {
                originalFee = BigDecimal.valueOf(amount);
            }
            BigDecimal savedFee = originalFee.subtract(paidFee);
            if (savedFee.signum() < 0) {
                savedFee = BigDecimal.ZERO;
            }

            int participantCount = Math.max(1, targetIds.size());
            DeliverySettlement settlement = DeliverySettlement.of(
                    requester,
                    chatRoom.getPost(),
                    cart,
                    participantCount,
                    originalFee,
                    paidFee,
                    savedFee,
                    amount,
                    processedAt
            );
            deliverySettlementRepository.save(settlement);
            results = List.of(new SettlementTransferResponseDto.TransferResult(
                    requester.getId(),
                    requester.getNickname(),
                    amount,
                    requester.getPointOrDefault()
            ));
        } else {
            results = List.of();
        }

        List<DeliverySettlement> currentSettlements = deliverySettlementRepository.findByCart_Id(cart.getId());
        int escrowTotal = currentSettlements.stream()
                .mapToInt(DeliverySettlement::getPointsCharged)
                .sum();
        chatRoom.updateEscrowTotal(escrowTotal);

        Set<Long> paidUserIds = currentSettlements.stream()
                .map(DeliverySettlement::getUser)
                .filter(Objects::nonNull)
                .map(User::getId)
                .collect(Collectors.toSet());
        boolean readyToStart = escrowTotal >= chatRoom.getEscrowTargetPoint() && paidUserIds.containsAll(targetIds);
        if (readyToStart) {
            chatRoom.updateStatus(ChatRoomStatus.ORDERING);
        }

        SettlementTransferResponseDto.HostResult hostResult = new SettlementTransferResponseDto.HostResult(
                host.getId(),
                host.getNickname(),
                0,
                host.getPointOrDefault()
        );
        SettlementTransferResponseDto.EscrowInfo escrowInfo = new SettlementTransferResponseDto.EscrowInfo(
                chatRoom.getEscrowTargetPoint(),
                chatRoom.getEscrowTotalPoint(),
                readyToStart
        );

        return new SettlementTransferResponseDto(
                cart.getId(),
                chatRoom.getId(),
                processedAt,
                results,
                hostResult,
                escrowInfo
        );
    }

    private String sanitizeMemo(String memo) {
        if (!StringUtils.hasText(memo)) {
            return null;
        }
        String normalized = memo.trim();
        if (normalized.length() > 255) {
            throw new IllegalArgumentException("메모는 255자를 넘을 수 없습니다.");
        }
        return normalized;
    }

    private void settleDeliveryCosts(SharedCart cart) {
        ChatRoom chatRoom = cart.getChatRoom();
        if (chatRoom == null) {
            return;
        }

        Post post = chatRoom.getPost();
        if (post == null || post.getPostType() != PostType.DELIVERY) {
            return;
        }

        DeliveryDetail deliveryDetail = post.getDeliveryDetail();
        if (deliveryDetail == null || deliveryDetail.getDeliveryFee() == null) {
            log.debug("배달비 정보가 없어 정산을 건너뜁니다. cartId={}", cart.getId());
            return;
        }

        BigDecimal originalFee = normalizeCurrency(deliveryDetail.getDeliveryFee());
        List<Long> participantIdList = chatRoomParticipantRepository.findUserIdsByChatRoomId(chatRoom.getId());
        Set<Long> participantIds = participantIdList.stream()
            .collect(Collectors.toCollection(LinkedHashSet::new));
        if (participantIds.isEmpty() && cart.getHost() != null && cart.getHost().getId() != null) {
            participantIds.add(cart.getHost().getId());
        }

        Map<Long, User> participants = userRepository.findAllById(participantIds).stream()
                .collect(Collectors.toMap(User::getId, user -> user));

        if (cart.getHost() != null && cart.getHost().getId() != null && !participants.containsKey(cart.getHost().getId())) {
            userRepository.findById(cart.getHost().getId()).ifPresent(user -> participants.put(user.getId(), user));
        }

        if (participants.isEmpty()) {
            log.debug("정산 대상 사용자가 없어 정산을 생략합니다. cartId={}", cart.getId());
            return;
        }

        int participantCount = Math.max(1, participants.size());
        BigDecimal paidFeePerUser = originalFee.divide(BigDecimal.valueOf(participantCount), 0, RoundingMode.HALF_UP);
        BigDecimal savedFeeCandidate = originalFee.subtract(paidFeePerUser);
        BigDecimal savedFeePerUser = savedFeeCandidate.signum() < 0 ? BigDecimal.ZERO : savedFeeCandidate;

        LocalDateTime settledAt = cart.getCompletedAt() != null ? cart.getCompletedAt() : LocalDateTime.now();
        List<DeliverySettlement> settlements = participants.values().stream()
                .map(user -> createSettlementRecord(user, post, cart, participantCount,
                        originalFee, paidFeePerUser, savedFeePerUser, settledAt))
                .toList();

        deliverySettlementRepository.saveAll(settlements);
    }

    private Set<Long> collectParticipantIds(ChatRoom chatRoom, User host) {
        if (chatRoom == null || chatRoom.getId() == null) {
            return Set.of();
        }
        Set<Long> participantIds = chatRoomParticipantRepository.findUserIdsByChatRoomId(chatRoom.getId()).stream()
                .filter(Objects::nonNull)
                .collect(Collectors.toCollection(LinkedHashSet::new));
        if (host != null && host.getId() != null) {
            participantIds.add(host.getId());
        }
        return participantIds;
    }

    private Integer calculateDeliveryFeePerPerson(Integer deliveryFee, Set<Long> participantIds) {
        if (deliveryFee == null) {
            return null;
        }
        long participantCount = participantIds == null ? 0 : participantIds.stream().filter(Objects::nonNull).count();
        if (participantCount <= 0) {
            return deliveryFee;
        }
        return BigDecimal.valueOf(deliveryFee)
                .divide(BigDecimal.valueOf(participantCount), 0, RoundingMode.HALF_UP)
                .intValue();
    }

    private BigDecimal resolveOriginalDeliveryFeeForPost(Post post) {
        if (post == null) {
            return null;
        }
        DeliveryDetail deliveryDetail = post.getDeliveryDetail();
        if (deliveryDetail == null || deliveryDetail.getDeliveryFee() == null) {
            return null;
        }
        return normalizeCurrency(deliveryDetail.getDeliveryFee());
    }

    private DeliverySettlement createSettlementRecord(User user,
                                                      Post post,
                                                      SharedCart cart,
                                                      int participantCount,
                                                      BigDecimal originalFee,
                                                      BigDecimal paidFee,
                                                      BigDecimal savedFee,
                                                      LocalDateTime settledAt) {
        int pointsToDeduct = paidFee.intValueExact();
        user.decreasePoint(pointsToDeduct);

        return DeliverySettlement.of(
                user,
                post,
                cart,
                participantCount,
                originalFee,
                paidFee,
                savedFee,
                pointsToDeduct,
                settledAt
        );
    }

    private BigDecimal normalizeCurrency(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value.setScale(0, RoundingMode.HALF_UP);
    }

    private SharedCart resolveCartForSettlement(ChatRoom chatRoom, Long cartId) {
        if (chatRoom == null || chatRoom.getId() == null) {
            throw new EntityNotFoundException("채팅방 정보를 확인할 수 없습니다.");
        }

        Long roomId = chatRoom.getId();
        if (cartId != null) {
            return sharedCartRepository.findByIdAndChatRoom_Id(cartId, roomId)
                    .orElseThrow(() -> new EntityNotFoundException("정산 대상 장바구니를 찾을 수 없습니다."));
        }

        return sharedCartRepository.findTopByChatRoom_IdOrderByCreatedAtDesc(roomId)
                .orElseThrow(() -> new EntityNotFoundException("정산 대상 장바구니가 없습니다."));
    }

    private void requireUser(Long userId) {
        if (userId == null) {
            throw new EntityNotFoundException("사용자 정보를 확인할 수 없습니다.");
        }
    }

    private ChatRoomParticipant getParticipationOrThrow(Long roomId, Long userId) {
        return chatRoomParticipantRepository
                .findByChatRoom_IdAndUser_Id(roomId, userId)
                .orElseGet(() -> {
                    if (!chatRoomRepository.existsById(roomId)) {
                        throw new EntityNotFoundException("채팅방을 찾을 수 없습니다.");
                    }
                    throw new ForbiddenException("채팅방 접근 권한이 없습니다.");
                });
    }

    private User resolveHostOrThrow(ChatRoom chatRoom) {
        if (chatRoom.getPost() == null || chatRoom.getPost().getAuthor() == null) {
            throw new EntityNotFoundException("채팅방의 방장을 확인할 수 없습니다.");
        }
        return chatRoom.getPost().getAuthor();
    }

    private void validateHost(Long userId, User host) {
        if (userId == null || host.getId() == null || !host.getId().equals(userId)) {
            throw new ForbiddenException("방장만 수행할 수 있는 작업입니다.");
        }
    }

    private void validateCartParticipant(SharedCart cart, ChatRoomParticipant participant) {
        if (participant == null || participant.getChatRoom() == null || cart.getChatRoom() == null) {
            throw new ForbiddenException("장바구니 참여자를 확인할 수 없습니다.");
        }
        if (!Objects.equals(participant.getChatRoom().getId(), cart.getChatRoom().getId())) {
            throw new ForbiddenException("해당 장바구니에 참여한 사용자만 요청할 수 있습니다.");
        }
    }

    private void publishAfterCommit(Runnable action) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            action.run();
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                action.run();
            }
        });
    }
}
