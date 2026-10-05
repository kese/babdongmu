package com.example.capstone.service;

import com.example.capstone.domain.jointorder.*;
import com.example.capstone.domain.post.Post;
import com.example.capstone.domain.post.PostStatus;
import com.example.capstone.domain.post.PostParticipant;
import com.example.capstone.domain.post.DeliveryDetail;
import com.example.capstone.domain.chat.ChatRoom;
import com.example.capstone.domain.chat.ChatRoomParticipant;
import com.example.capstone.domain.chat.ChatRoomType;
import com.example.capstone.domain.chat.ChatMessage;
import com.example.capstone.dto.jointorder.*;
import com.example.capstone.dto.notification.JointOrderRequestNotificationDto;
import com.example.capstone.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;
import jakarta.persistence.EntityNotFoundException;

@Slf4j
@Service
@RequiredArgsConstructor
public class JointOrderService {

    private final JointOrderRequestRepository jointOrderRequestRepository;
    private final PostRepository postRepository;
    private final ChatRoomRepository chatRoomRepository;
    private final ChatRoomParticipantRepository chatRoomParticipantRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final PostParticipantRepository postParticipantRepository;
    private final DeliveryDetailRepository deliveryDetailRepository;
    private final SharedCartService sharedCartService;
    private final FcmService fcmService;

    @Transactional(readOnly = true)
    public MyPostResponseDto getMyMatchablePost(Long userId) {
        // 사용자의 모집 중인 배달 게시글 조회
        List<Post> userPosts = postRepository.findByAuthorIdAndStatusAndPostType(
            userId, PostStatus.ACTIVE, com.example.capstone.domain.post.PostType.DELIVERY);
        
        if (userPosts.isEmpty()) {
            throw new IllegalStateException("매칭 가능한 게시글이 없습니다. 모집 중인 게시글을 먼저 생성해주세요.");
        }
        
        // 가장 최근 게시글 반환
        Post post = userPosts.get(0);
        return MyPostResponseDto.from(post);
    }

    @Transactional(readOnly = true)
    public List<MatchablePostDto> getMatchablePosts(String storeName, String locationName, Integer deliveryFee, Long userId) {
        // 음식점 + 배달 장소(POI 명칭)가 같은 게시글만 대상으로 검색
        List<Post> matchablePosts = postRepository.findMatchablePostsByLocationName(
            storeName, locationName, userId);
        
        return matchablePosts.stream()
                .map(MatchablePostDto::from)
                .collect(Collectors.toList());
    }

    @Transactional
    public JointOrderRequestResponseDto createJointOrderRequest(CreateJointOrderRequestDto request, Long userId) {
        // 요청자 게시글 검증
        Post requesterPost = postRepository.findById(request.requesterPostId())
                .orElseThrow(() -> new EntityNotFoundException("요청자 게시글을 찾을 수 없습니다."));
        
        if (!requesterPost.getAuthor().getId().equals(userId)) {
            throw new IllegalStateException("본인의 게시글만 요청할 수 있습니다.");
        }
        
        if (!requesterPost.isActive()) {
            throw new IllegalStateException("모집 중인 게시글만 요청할 수 있습니다.");
        }
        
        // 대상 게시글 검증
        List<Post> targetPosts = request.targetPostIds().stream()
                .map(postId -> postRepository.findById(postId)
                        .orElseThrow(() -> new EntityNotFoundException("대상 게시글을 찾을 수 없습니다: " + postId)))
                .collect(Collectors.toList());
        
        // 중복 요청 방지 검증
        for (Post targetPost : targetPosts) {
            List<JointOrderRequest> existingRequests = jointOrderRequestRepository
                    .findPendingRequestsForPost(targetPost.getId(), JointOrderStatus.PENDING);
            if (!existingRequests.isEmpty()) {
                throw new IllegalStateException("이미 진행 중인 합동 주문 요청이 있는 게시글이 있습니다: " + targetPost.getTitle());
            }
        }
        
        // 합동 주문 요청 생성
        JointOrderRequest jointOrderRequest = JointOrderRequest.builder()
                .requester(requesterPost.getAuthor())
                .requesterPost(requesterPost)
                .build();
        
        // 대상 게시글 추가
        for (Post targetPost : targetPosts) {
            JointOrderTarget target = JointOrderTarget.builder()
                    .jointOrderRequest(jointOrderRequest)
                    .targetPost(targetPost)
                    .build();
            jointOrderRequest.getTargets().add(target);
        }
        
        jointOrderRequestRepository.save(jointOrderRequest);
        
        // FCM 알림 전송 (대상자들에게)
        sendJointOrderRequestNotifications(jointOrderRequest, targetPosts);
        
        return new JointOrderRequestResponseDto(
            jointOrderRequest.getId(),
            "합동 주문 요청이 전송되었습니다."
        );
    }

    @Transactional(readOnly = true)
    public JointOrderStatusDto getRequestStatus(Long requestId, Long userId) {
        JointOrderRequest request = jointOrderRequestRepository.findByIdWithDetails(requestId)
                .orElseThrow(() -> new EntityNotFoundException("합동 주문 요청을 찾을 수 없습니다."));
        
        // 권한 검증 (요청자 또는 응답자만 조회 가능)
        if (!request.getRequester().getId().equals(userId) && !isResponder(request, userId)) {
            throw new IllegalStateException("요청 상태를 조회할 권한이 없습니다.");
        }
        
        List<JointOrderResponseDto> responses = request.getResponses().stream()
                .map(response -> new JointOrderResponseDto(
                    response.getPost().getId(),
                    response.getResponder().getNickname(),
                    response.isAccepted(),
                    response.getResponseTime()
                ))
                .collect(Collectors.toList());
        
        return new JointOrderStatusDto(
            request.getId(),
            request.getRequester().getNickname(),
            request.getRequesterPost().getId(),
            request.getTargets().stream()
                    .map(target -> target.getTargetPost().getId())
                    .collect(Collectors.toList()),
            request.getCreatedAt(),
            request.getStatus().name().toLowerCase(),
            responses
        );
    }

    @Transactional
    public JointOrderResponseDto respondToRequest(Long requestId, RespondToRequestDto request, Long userId) {
        JointOrderRequest jointOrderRequest = jointOrderRequestRepository.findByIdWithDetails(requestId)
                .orElseThrow(() -> new EntityNotFoundException("합동 주문 요청을 찾을 수 없습니다."));
        
        // 응답 가능 상태 검증
        if (!jointOrderRequest.canAccept()) {
            throw new IllegalStateException("응답할 수 없는 요청입니다.");
        }
        
        // 대상 게시글 찾기
        Post targetPost = jointOrderRequest.getTargets().stream()
                .map(JointOrderTarget::getTargetPost)
                .filter(post -> post.getAuthor().getId().equals(userId))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("응답 권한이 없는 게시글입니다."));
        
        // 중복 응답 방지
        boolean alreadyResponded = jointOrderRequest.getResponses().stream()
                .anyMatch(response -> response.getPost().getId().equals(targetPost.getId()));
        if (alreadyResponded) {
            throw new IllegalStateException("이미 응답한 요청입니다.");
        }
        
        // 응답 생성
        JointOrderResponse response = JointOrderResponse.builder()
                .jointOrderRequest(jointOrderRequest)
                .post(targetPost)
                .responder(targetPost.getAuthor())
                .accepted(request.accepted())
                .build();
        
        jointOrderRequest.getResponses().add(response);
        jointOrderRequestRepository.save(jointOrderRequest);
        
        // 상태 업데이트
        updateRequestStatus(jointOrderRequest);
        
        return new JointOrderResponseDto(
            request.accepted(),
            request.accepted() ? "합동 주문 요청을 수락했습니다." : "합동 주문 요청을 거절했습니다."
        );
    }

    @Transactional(readOnly = true)
    public List<PendingRequestDto> getPendingRequests(Long userId) {
        List<JointOrderRequest> pendingRequests = jointOrderRequestRepository
                .findPendingRequestsForUser(userId, JointOrderStatus.PENDING);
        
        return pendingRequests.stream()
                .map(request -> new PendingRequestDto(
                    request.getId(),
                    request.getRequester().getNickname(),
                    request.getRequesterPost().getId(),
                    request.getTargets().stream()
                            .map(target -> target.getTargetPost().getId())
                            .collect(Collectors.toList()),
                    request.getCreatedAt(),
                    request.getStatus().name().toLowerCase()
                ))
                .collect(Collectors.toList());
    }

    @Transactional
    public CreateChatRoomResponseDto createJointChatRoom(CreateChatRoomRequestDto request, Long userId) {
        JointOrderRequest jointOrderRequest = jointOrderRequestRepository.findByIdWithDetails(request.requestId())
                .orElseThrow(() -> new EntityNotFoundException("합동 주문 요청을 찾을 수 없습니다."));
        
        // 권한 및 상태 검증
        if (!jointOrderRequest.getRequester().getId().equals(userId)) {
            throw new IllegalStateException("채팅방 생성은 요청자만 가능합니다.");
        }
        
        if (jointOrderRequest.getStatus() != JointOrderStatus.ACCEPTED) {
            throw new IllegalStateException("매칭이 완료된 요청만 채팅방을 생성할 수 있습니다.");
        }

        // 요청된 postIds가 실제 요청에 포함된 게시글들인지 검증
        List<Long> requestedPostIds = request.postIds();
        if (requestedPostIds.isEmpty()) {
            throw new IllegalArgumentException("게시글 ID 목록은 비어있을 수 없습니다.");
        }

        Set<Long> actualPostIds = new HashSet<>();
        actualPostIds.add(jointOrderRequest.getRequesterPost().getId());
        actualPostIds.addAll(jointOrderRequest.getTargets().stream()
                .map(target -> target.getTargetPost().getId())
                .collect(Collectors.toSet()));

        if (!actualPostIds.equals(new HashSet<>(requestedPostIds))) {
            throw new IllegalArgumentException("요청된 게시글 ID가 매칭된 게시글과 일치하지 않습니다.");
        }

        // 모든 게시글 조회
        List<Post> allPosts = new ArrayList<>();
        allPosts.add(jointOrderRequest.getRequesterPost());
        allPosts.addAll(jointOrderRequest.getTargets().stream()
                .map(JointOrderTarget::getTargetPost)
                .collect(Collectors.toList()));

        // 대표 게시글(요청자 게시글) 선정
        Post representativePost = jointOrderRequest.getRequesterPost();
        
        // 대표 게시글의 기존 채팅방을 그룹방으로 승격
        ChatRoom groupChatRoom = chatRoomRepository.findByPost_Id(representativePost.getId())
                .orElseThrow(() -> new EntityNotFoundException("대표 게시글의 채팅방을 찾을 수 없습니다."));

        // 그룹방 제목 생성: "A + B (+ C ...)"
        String roomTitle = allPosts.stream()
                .map(Post::getTitle)
                .collect(Collectors.joining(" + "));
        
        // 채팅방을 그룹방으로 변경
        groupChatRoom.updateRoomName(roomTitle);
        groupChatRoom.updateRoomType(ChatRoomType.GROUP);
        chatRoomRepository.save(groupChatRoom);

        // 대표 게시글의 모집/배달 세부 값을 가장 큰 값으로 업데이트
        DeliveryDetail representativeDetail = representativePost.getDeliveryDetail();
        if (representativeDetail != null) {
            BigDecimal maxTargetAmount = allPosts.stream()
                    .map(post -> post.getDeliveryDetail() != null ? post.getDeliveryDetail().getTargetAmount() : BigDecimal.ZERO)
                    .max(BigDecimal::compareTo)
                    .orElse(BigDecimal.ZERO);
            
            BigDecimal maxDeliveryFee = allPosts.stream()
                    .map(post -> post.getDeliveryDetail() != null ? post.getDeliveryDetail().getDeliveryFee() : BigDecimal.ZERO)
                    .max(BigDecimal::compareTo)
                    .orElse(BigDecimal.ZERO);

            BigDecimal maxMinOrderAmount = allPosts.stream()
                    .map(post -> {
                        DeliveryDetail detail = post.getDeliveryDetail();
                        return detail != null ? detail.getMinOrderAmount() : null;
                    })
                    .filter(Objects::nonNull)
                    .max(BigDecimal::compareTo)
                    .orElse(representativeDetail.getMinOrderAmount());
            
            representativeDetail.update(
                    representativeDetail.getRestaurantName(),
                    representativeDetail.getRestaurantAddress(),
                    representativeDetail.getRestaurantPhone(),
                    maxDeliveryFee,
                    representativeDetail.getOrderLink(),
                    representativeDetail.getDeliveryAddress(),
                    representativeDetail.getDeliveryLatitude(),
                    representativeDetail.getDeliveryLongitude(),
                    maxTargetAmount,
                    representativeDetail.getCurrentAmount(),
                    maxMinOrderAmount,
                    representativeDetail.getCategory()
            );
            deliveryDetailRepository.save(representativeDetail);
        }

        Integer maxParticipants = allPosts.stream()
                .map(Post::getMaxParticipants)
                .filter(Objects::nonNull)
                .max(Integer::compareTo)
                .orElse(representativePost.getMaxParticipants());

        if (maxParticipants != null) {
            representativePost.updateMaxParticipants(maxParticipants);
        }

        LocalDateTime latestMeetingTime = allPosts.stream()
                .map(Post::getMeetingTime)
                .filter(Objects::nonNull)
                .max(LocalDateTime::compareTo)
                .orElse(null);

        if (latestMeetingTime != null) {
            representativePost.updateMeetingInfo(representativePost.getMeetingPlace(), latestMeetingTime);
        }

        postRepository.save(representativePost);

        // 모든 게시글의 참여자를 그룹방에 추가
        Set<Long> existingParticipantIds = chatRoomParticipantRepository.findByChatRoom_Id(groupChatRoom.getId())
                .stream()
                .map(p -> p.getUser() != null ? p.getUser().getId() : null)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        for (Post post : allPosts) {
            List<PostParticipant> postParticipants = postParticipantRepository.findByPostIdWithUser(post.getId());
            for (PostParticipant postParticipant : postParticipants) {
                if (postParticipant.getUser() != null && !existingParticipantIds.contains(postParticipant.getUser().getId())) {
                    ChatRoomParticipant participant = ChatRoomParticipant.builder()
                            .chatRoom(groupChatRoom)
                            .user(postParticipant.getUser())
                            .joinedAt(LocalDateTime.now())
                            .build();
                    chatRoomParticipantRepository.save(participant);
                    existingParticipantIds.add(postParticipant.getUser().getId());
                }
            }
        }

        int totalParticipants = existingParticipantIds.size();
        if (totalParticipants > 0) {
            representativePost.setCurrentParticipants(totalParticipants);
            
            // maxParticipants 자동 조정: 실제 참여자 수가 max를 초과하면 상향 조정
            Integer currentMax = representativePost.getMaxParticipants();
            if (currentMax == null || totalParticipants > currentMax) {
                representativePost.updateMaxParticipants(totalParticipants);
                log.info("합동 주문 그룹방 maxParticipants 자동 조정: {} → {}", currentMax, totalParticipants);
            }
            
            // 채팅방 maxCapacity도 동일하게 조정
            groupChatRoom.updateMaxCapacity(representativePost.getMaxParticipants());
            chatRoomRepository.save(groupChatRoom);
            
            postRepository.save(representativePost);
        }

        // 대표 게시글이 아닌 다른 게시글들의 채팅방 비활성화 및 메시지 이전
        for (Post post : allPosts) {
            if (!post.getId().equals(representativePost.getId())) {
                post.updateStatus(PostStatus.CLOSED);
                post.setCurrentParticipants(0);
                postRepository.save(post);
                ChatRoom oldChatRoom = chatRoomRepository.findByPost_Id(post.getId()).orElse(null);
                if (oldChatRoom != null) {
                    // 기존 채팅방의 모든 메시지를 그룹 채팅방으로 이전
                    List<ChatMessage> oldMessages = chatMessageRepository.findByChatRoom_Id(oldChatRoom.getId());
                    for (ChatMessage oldMessage : oldMessages) {
                        oldMessage.updateChatRoom(groupChatRoom);
                    }
                    chatMessageRepository.saveAll(oldMessages);
                    
                    // 기존 채팅방의 모든 참여자 삭제
                    List<ChatRoomParticipant> oldParticipants = chatRoomParticipantRepository.findByChatRoom_Id(oldChatRoom.getId());
                    for (ChatRoomParticipant oldParticipant : oldParticipants) {
                        chatRoomParticipantRepository.delete(oldParticipant);
                    }
                    // 채팅방 비활성화
                    oldChatRoom.deactivate();
                    chatRoomRepository.save(oldChatRoom);
                }
            }
        }
        
        // 공용 장바구니 자동 활성화
        sharedCartService.activate(jointOrderRequest.getRequester().getId(), groupChatRoom.getId());
        
        return new CreateChatRoomResponseDto(
            groupChatRoom.getId(),
            "합동 주문 매칭이 완료되어 그룹 채팅방이 생성되었습니다."
        );
    }

    private boolean isResponder(JointOrderRequest request, Long userId) {
        return request.getTargets().stream()
                .anyMatch(target -> target.getTargetPost().getAuthor().getId().equals(userId));
    }

    private void updateRequestStatus(JointOrderRequest request) {
        if (!request.isAllResponded()) {
            return; // 아직 모두 응답하지 않음
        }
        
        if (request.isAllAccepted()) {
            request.markAsAccepted();
        } else {
            request.markAsRejected();
        }
        
        jointOrderRequestRepository.save(request);
    }

    /**
     * 합동 주문 요청 FCM 알림 전송
     * @param jointOrderRequest 합동 주문 요청
     * @param targetPosts 대상 게시글 목록
     */
    private void sendJointOrderRequestNotifications(JointOrderRequest jointOrderRequest, List<Post> targetPosts) {
        Post requesterPost = jointOrderRequest.getRequesterPost();
        String storeName = requesterPost.getDeliveryDetail() != null 
                ? requesterPost.getDeliveryDetail().getRestaurantName() 
                : "";
        String deliveryPlace = requesterPost.getLocationName() != null 
                ? requesterPost.getLocationName() 
                : "";
        String orderTime = requesterPost.getMeetingTime() != null 
                ? requesterPost.getMeetingTime().toString() 
                : "";
        
        for (Post targetPost : targetPosts) {
            Long recipientUserId = targetPost.getAuthor().getId();
            
            JointOrderRequestNotificationDto payload = new JointOrderRequestNotificationDto(
                    jointOrderRequest.getId(),
                    targetPost.getId(),
                    jointOrderRequest.getRequester().getId(),
                    jointOrderRequest.getRequester().getNickname(),
                    storeName,
                    deliveryPlace,
                    orderTime
            );
            
            log.info("📨 합동 주문 요청 FCM 전송 예약 - requestId={}, targetPostId={}, recipient={}", 
                    jointOrderRequest.getId(), targetPost.getId(), recipientUserId);
            
            fcmService.sendJointOrderRequestNotification(recipientUserId, payload);
        }
    }
}
