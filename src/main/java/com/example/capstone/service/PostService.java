package com.example.capstone.service;

import com.example.capstone.domain.User;
import com.example.capstone.domain.chat.ChatRoom;
import com.example.capstone.domain.chat.ChatRoomParticipant;
import com.example.capstone.domain.chat.ChatRoomType;
import com.example.capstone.domain.post.DeliveryDetail;
import com.example.capstone.domain.post.ParticipantRole;
import com.example.capstone.domain.post.Post;
import com.example.capstone.domain.post.PostMeetDetail;
import com.example.capstone.domain.post.PostParticipant;
import com.example.capstone.domain.post.PostStatus;
import com.example.capstone.domain.post.PostType;
import com.example.capstone.dto.post.JoinResponseDto;
import com.example.capstone.dto.post.PostCreateRequestDto;
import com.example.capstone.dto.post.PostCreateResponseDto;
import com.example.capstone.dto.post.PostDetailResponseDto;
import com.example.capstone.dto.post.PostListResponseDto;
import com.example.capstone.dto.post.PostUpdateRequestDto;
import com.example.capstone.repository.ChatRoomParticipantRepository;
import com.example.capstone.repository.ChatRoomRepository;
import com.example.capstone.repository.DeliveryDetailRepository;
import com.example.capstone.repository.PostMeetDetailRepository;
import com.example.capstone.repository.PostParticipantRepository;
import com.example.capstone.repository.PostRepository;
import com.example.capstone.repository.UserRepository;
import com.example.capstone.util.PublicLocation;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PostService {

    private final PostRepository postRepository;
    private final PostParticipantRepository postParticipantRepository;
    private final UserRepository userRepository;
    private final DeliveryDetailRepository deliveryDetailRepository;
    private final PostMeetDetailRepository postMeetDetailRepository;
    private final ChatRoomRepository chatRoomRepository;
    private final ChatRoomParticipantRepository chatRoomParticipantRepository;
    private final FcmService fcmService;

    private static final String DEFAULT_DELIVERY_ADDRESS = PublicLocation.GENERIC_LABEL;

    @Transactional
    public PostCreateResponseDto createPost(PostCreateRequestDto dto, Long userId) {
        User author = loadUserOrThrow(userId);

        PostType postType = parsePostType(dto.getPostType());
        LocalDateTime meetingTime = dto.getMeetingTime();
        String meetingPlace = dto.getMeetingPlace();
        String locationName = dto.getLocationName();

        if (postType == PostType.DELIVERY) {
            locationName = PublicLocation.safeLabel(dto.getLocationName());
            meetingPlace = locationName;
        }

        if (postType == PostType.MEET && dto.getMeetDetail() != null) {
            PostCreateRequestDto.MeetDetailDto meetDetailDto = dto.getMeetDetail();
            if (meetDetailDto.getMeetingTime() != null) {
                meetingTime = meetDetailDto.getMeetingTime();
            }
            if (meetDetailDto.getMeetingPlace() != null) {
                meetingPlace = meetDetailDto.getMeetingPlace();
            }
        }

        Post post = Post.builder()
                .author(author)
                .postType(postType)
                .status(PostStatus.ACTIVE)
                .title(dto.getTitle())
                .content(dto.getContent())
                .maxParticipants(dto.getMaxParticipants())
                .meetingPlace(meetingPlace)
                .meetingTime(meetingTime)
                .placeId(dto.getPlaceId())
                .locationLatitude(PublicLocation.approximateCoordinate(dto.getLocationLatitude()))
                .locationLongitude(PublicLocation.approximateCoordinate(dto.getLocationLongitude()))
                .locationName(locationName)
                .locationAddress(null)
                .build();

        Post savedPost = postRepository.save(post);

        if (postType == PostType.DELIVERY) {
            attachDeliveryDetail(savedPost, dto.getDeliveryDetail());
        } else if (postType == PostType.MEET) {
            attachMeetDetail(savedPost, dto.getMeetDetail());
        }

    ChatRoom chatRoom = chatRoomRepository.save(ChatRoom.builder()
        .post(savedPost)
        .roomName(savedPost.getTitle())
        .roomType(postType == PostType.MEET ? ChatRoomType.MEET : ChatRoomType.DELIVERY)
        .build());

        PostParticipant creator = PostParticipant.builder()
                .post(savedPost)
                .user(author)
                .role(ParticipantRole.CREATOR)
                .build();
        postParticipantRepository.save(creator);
    savedPost.setCurrentParticipants(1);

        chatRoomParticipantRepository.save(ChatRoomParticipant.builder()
                .chatRoom(chatRoom)
                .user(author)
                .joinedAt(LocalDateTime.now())
                .lastReadMessageId(null)
                .build());

        return PostCreateResponseDto.builder()
                .postId(savedPost.getId())
                .chatRoomId(chatRoom.getId())
                .build();
    }

    @Transactional
    public void updatePost(Long postId, PostUpdateRequestDto dto, Long userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new EntityNotFoundException("Post not found."));
        requirePostOwner(post, userId);

        post.updateBasicInfo(dto.getTitle(), dto.getContent(), dto.getMaxParticipants());

        if (post.getPostType() == PostType.DELIVERY) {
            updateDeliveryDetail(post, dto.getDeliveryDetail());
        } else if (post.getPostType() == PostType.MEET) {
            updateMeetDetail(post, dto.getMeetDetail());
        }

        LocalDateTime meetingTime = dto.getMeetingTime();
        String meetingPlace = dto.getMeetingPlace();
        if (post.getPostType() == PostType.MEET && dto.getMeetDetail() != null) {
            PostCreateRequestDto.MeetDetailDto meetDetailDto = dto.getMeetDetail();
            if (meetDetailDto.getMeetingTime() != null) {
                meetingTime = meetDetailDto.getMeetingTime();
            }
            if (meetDetailDto.getMeetingPlace() != null) {
                meetingPlace = meetDetailDto.getMeetingPlace();
            }
        }
        post.updateMeetingInfo(meetingPlace, meetingTime);
    }

    @Transactional
    public void deletePost(Long postId, Long userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new EntityNotFoundException("Post not found."));
        requirePostOwner(post, userId);
        post.changeStatus(PostStatus.DELETED);
    }

    @Transactional(readOnly = true)
    public List<PostListResponseDto> findAllPosts() {
        List<Post> posts = postRepository.findByStatusOrderByCreatedAtDesc(PostStatus.ACTIVE);
        return buildPostListResponse(posts);
    }

    @Transactional(readOnly = true)
    public List<PostListResponseDto> findMyPosts(Long userId) {
        ensureAuthenticated(userId);
    List<Post> posts = postRepository.findByAuthor_IdOrderByCreatedAtDesc(userId);
        return buildPostListResponse(posts);
    }

    @Transactional(readOnly = true)
    public List<PostListResponseDto> findMyJoinedPosts(Long userId) {
        ensureAuthenticated(userId);
        List<PostParticipant> participations = postParticipantRepository.findByUserIdWithPost(userId, ParticipantRole.CREATOR);
        if (participations.isEmpty()) {
            return Collections.emptyList();
        }
        List<Post> posts = participations.stream()
                .map(PostParticipant::getPost)
                .distinct()
                .sorted(Comparator.comparing(Post::getCreatedAt, Comparator.nullsLast(Comparator.naturalOrder())).reversed())
                .collect(Collectors.toList());
        return buildPostListResponse(posts);
    }

    @Transactional(readOnly = true)
    public PostDetailResponseDto findPostById(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new EntityNotFoundException("Post not found."));
        List<PostParticipant> participants = postParticipantRepository.findByPostIdWithUser(postId);
        return PostDetailResponseDto.of(post, participants.size(), participants);
    }

    @Transactional
    public void closeRecruitment(Long postId, Long userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new EntityNotFoundException("게시글을 찾을 수 없습니다."));
        
        User user = loadUserOrThrow(userId);
        
        // 권한 검증: 게시글 작성자 또는 채팅방 방장만 가능
        if (!post.getAuthor().getId().equals(userId)) {
            ChatRoom chatRoom = chatRoomRepository.findByPost_Id(postId)
                    .orElseThrow(() -> new EntityNotFoundException("채팅방을 찾을 수 없습니다."));
            
            // 채팅방 방장인지 확인
            boolean isHost = chatRoomParticipantRepository.existsByChatRoom_IdAndUser_IdAndHostTrue(
                    chatRoom.getId(), userId);
            
            if (!isHost) {
                throw new IllegalStateException("모집 상태를 변경할 권한이 없습니다.");
            }
        }
        
        // 이미 마감된 상태인지 확인
        if (!post.isActive()) {
            throw new IllegalStateException("이미 모집이 마감된 게시글입니다.");
        }
        
        // 모집 상태 변경
        post.updateStatus(PostStatus.CLOSED);
        postRepository.save(post);
    }

    @Transactional
    public JoinResponseDto joinPost(Long postId, Long userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new EntityNotFoundException("Post not found."));
        if (!post.isActive()) {
            throw new IllegalStateException("Post is not recruiting members.");
        }
        
        // 채팅방 상태 검증 추가 - 주문 시작 후 참여 방지
        ChatRoom chatRoom = chatRoomRepository.findByPost_Id(postId)
                .orElseThrow(() -> new EntityNotFoundException("Chat room not found."));
        if (chatRoom.getRoomStatus() != com.example.capstone.domain.chat.ChatRoomStatus.BEFORE_ORDER) {
            throw new IllegalStateException("모집이 마감되었습니다. 주문이 이미 진행 중입니다.");
        }
        User user = loadUserOrThrow(userId);
        if (postParticipantRepository.existsByPost_IdAndUser_Id(postId, userId)) {
            throw new IllegalStateException("User already joined this post.");
        }
        Integer maxParticipants = post.getMaxParticipants();
        long currentCount = postParticipantRepository.countByPost_Id(postId);
        if (maxParticipants != null && maxParticipants > 0 && currentCount >= maxParticipants) {
            throw new IllegalStateException("Post is full.");
        }

        PostParticipant participant = PostParticipant.builder()
                .post(post)
                .user(user)
                .role(ParticipantRole.MEMBER)
                .build();
        postParticipantRepository.save(participant);

    // chatRoom 변수는 이미 235번째 줄에서 선언됨
        if (chatRoomParticipantRepository.findByChatRoom_IdAndUser_Id(chatRoom.getId(), userId).isEmpty()) {
            chatRoomParticipantRepository.save(ChatRoomParticipant.builder()
                .chatRoom(chatRoom)
                .user(user)
                .joinedAt(LocalDateTime.now())
                .build());
        }

        int updatedCount = Math.toIntExact(currentCount + 1);
        post.setCurrentParticipants(updatedCount);

        // 게시글 방장에게 참여 알림 전송 (합동 주문과 별개)
        notifyHostOfNewParticipant(post, user);
        return JoinResponseDto.of(post, userId, updatedCount);
    }

    /**
     * 게시글 참여 시 방장에게 알림 전송
     * (합동 주문 매칭과는 별개의 단순 참여 알림)
     */
    private void notifyHostOfNewParticipant(Post post, User newParticipant) {
        Long hostId = post.getAuthor() != null ? post.getAuthor().getId() : null;
        Long participantId = newParticipant.getId();
        
        // 본인이 아닌 경우에만 방장에게 알림
        if (hostId != null && !hostId.equals(participantId)) {
            fcmService.sendPostJoinNotification(
                    hostId,
                    post.getId(),
                    resolveRequesterName(newParticipant),
                    post.getTitle()
            );
        }
    }

    private void attachDeliveryDetail(Post post, PostCreateRequestDto.DeliveryDetailDto deliveryDetailDto) {
        if (deliveryDetailDto == null) {
            throw new IllegalArgumentException("Delivery detail is required for delivery posts.");
        }
        if (deliveryDetailDto.getTargetAmount() == null) {
            throw new IllegalArgumentException("Target amount is required for delivery posts.");
        }
        if (deliveryDetailDto.getDeliveryFee() == null) {
            throw new IllegalArgumentException("Delivery fee is required for delivery posts.");
        }
        String deliveryAddress = resolveDeliveryAddress(deliveryDetailDto.getDeliveryAddress(), null);
        BigDecimal currentAmount = deliveryDetailDto.getCurrentAmount() != null
                ? deliveryDetailDto.getCurrentAmount()
                : BigDecimal.ZERO;
        DeliveryDetail detail = DeliveryDetail.builder()
                .post(post)
                .restaurantName(deliveryDetailDto.getRestaurantName())
                .restaurantAddress(deliveryDetailDto.getRestaurantAddress())
                .restaurantPhone(deliveryDetailDto.getRestaurantPhone())
                .deliveryFee(deliveryDetailDto.getDeliveryFee())
                .orderLink(deliveryDetailDto.getOrderLink())
                .deliveryAddress(deliveryAddress)
                .targetAmount(deliveryDetailDto.getTargetAmount())
                .currentAmount(currentAmount)
                .minOrderAmount(deliveryDetailDto.getMinOrderAmount())
                .category(deliveryDetailDto.getCategory())
                .build();
        deliveryDetailRepository.save(detail);
    }

    private void attachMeetDetail(Post post, PostCreateRequestDto.MeetDetailDto meetDetailDto) {
        if (meetDetailDto == null) {
            throw new IllegalArgumentException("Meet detail is required for meet posts.");
        }
        validateMeetDetail(meetDetailDto);
        PostMeetDetail meetDetail = PostMeetDetail.builder()
                .post(post)
                .meetingPlace(meetDetailDto.getMeetingPlace())
                .meetingTime(meetDetailDto.getMeetingTime())
                .additionalNotes(meetDetailDto.getAdditionalNotes())
                .build();
        postMeetDetailRepository.save(meetDetail);
    }

    private List<PostListResponseDto> buildPostListResponse(List<Post> posts) {
        if (posts.isEmpty()) {
            return Collections.emptyList();
        }
        Map<Long, Integer> participantCounts = aggregateParticipantCounts(posts);
        return posts.stream()
                .map(post -> {
                    int fallbackCount = post.getCurrentParticipants() != null ? post.getCurrentParticipants() : 0;
                    int participantCount = participantCounts.getOrDefault(post.getId(), fallbackCount);
                    return PostListResponseDto.of(post, participantCount);
                })
                .collect(Collectors.toList());
    }

    private void updateDeliveryDetail(Post post, PostCreateRequestDto.DeliveryDetailDto deliveryDetailDto) {
        if (deliveryDetailDto == null) {
            throw new IllegalArgumentException("Delivery detail is required for delivery posts.");
        }
        if (deliveryDetailDto.getTargetAmount() == null) {
            throw new IllegalArgumentException("Target amount is required for delivery posts.");
        }
        DeliveryDetail detail = post.getDeliveryDetail();
        if (detail == null) {
            String deliveryAddress = resolveDeliveryAddress(deliveryDetailDto.getDeliveryAddress(), null);
            detail = DeliveryDetail.builder()
                    .post(post)
                    .restaurantName(deliveryDetailDto.getRestaurantName())
                    .restaurantAddress(deliveryDetailDto.getRestaurantAddress())
                    .restaurantPhone(deliveryDetailDto.getRestaurantPhone())
                    .deliveryFee(deliveryDetailDto.getDeliveryFee())
                    .orderLink(deliveryDetailDto.getOrderLink())
                    .deliveryAddress(deliveryAddress)
                    .deliveryLatitude(PublicLocation.approximateCoordinate(deliveryDetailDto.getDeliveryLatitude()))
                    .deliveryLongitude(PublicLocation.approximateCoordinate(deliveryDetailDto.getDeliveryLongitude()))
                    .targetAmount(deliveryDetailDto.getTargetAmount())
                    .currentAmount(deliveryDetailDto.getCurrentAmount())
                    .minOrderAmount(deliveryDetailDto.getMinOrderAmount())
                    .category(deliveryDetailDto.getCategory())
                    .build();
        } else {
            String deliveryAddress = resolveDeliveryAddress(deliveryDetailDto.getDeliveryAddress(), detail.getDeliveryAddress());
            detail.update(
                    deliveryDetailDto.getRestaurantName(),
                    deliveryDetailDto.getRestaurantAddress(),
                    deliveryDetailDto.getRestaurantPhone(),
                    deliveryDetailDto.getDeliveryFee(),
                    deliveryDetailDto.getOrderLink(),
                    deliveryAddress,
                    PublicLocation.approximateCoordinate(deliveryDetailDto.getDeliveryLatitude()),
                    PublicLocation.approximateCoordinate(deliveryDetailDto.getDeliveryLongitude()),
                    deliveryDetailDto.getTargetAmount(),
                    deliveryDetailDto.getCurrentAmount(),
                    deliveryDetailDto.getMinOrderAmount(),
                    deliveryDetailDto.getCategory()
            );
        }
        detail.assignPost(post);
        deliveryDetailRepository.save(detail);
    }

    private void updateMeetDetail(Post post, PostCreateRequestDto.MeetDetailDto meetDetailDto) {
        if (meetDetailDto == null) {
            throw new IllegalArgumentException("Meet detail is required for meet posts.");
        }
        validateMeetDetail(meetDetailDto);
        PostMeetDetail detail = post.getMeetDetail();
        if (detail == null) {
            detail = PostMeetDetail.builder()
                    .post(post)
                    .meetingPlace(meetDetailDto.getMeetingPlace())
                    .meetingTime(meetDetailDto.getMeetingTime())
                    .additionalNotes(meetDetailDto.getAdditionalNotes())
                    .build();
        } else {
            detail.update(meetDetailDto.getMeetingPlace(), meetDetailDto.getMeetingTime(), meetDetailDto.getAdditionalNotes());
        }
        detail.assignPost(post);
        postMeetDetailRepository.save(detail);
    }

    private void validateMeetDetail(PostCreateRequestDto.MeetDetailDto meetDetailDto) {
        if (meetDetailDto.getMeetingPlace() == null || meetDetailDto.getMeetingPlace().isBlank()) {
            throw new IllegalArgumentException("Meeting place is required for meet posts.");
        }
        if (meetDetailDto.getMeetingTime() == null) {
            throw new IllegalArgumentException("Meeting time is required for meet posts.");
        }
    }

    private Map<Long, Integer> aggregateParticipantCounts(List<Post> posts) {
        List<Long> postIds = posts.stream().map(Post::getId).toList();
        return postParticipantRepository.countByPostIds(postIds).stream()
                .collect(Collectors.toMap(
                        PostParticipantRepository.PostParticipantCount::getPostId,
                        entry -> entry.getParticipantCount().intValue()
                ));
    }

    private String resolveRequesterName(User requester) {
        if (requester == null) {
            return "";
        }
        if (StringUtils.hasText(requester.getNickname())) {
            return requester.getNickname();
        }
        if (StringUtils.hasText(requester.getUsername())) {
            return requester.getUsername();
        }
        return "사용자";
    }

    private void requirePostOwner(Post post, Long userId) {
        ensureAuthenticated(userId);
        if (post.getAuthor() == null || !post.getAuthor().getId().equals(userId)) {
            throw new IllegalStateException("Only the author can modify this post.");
        }
    }

    private PostType parsePostType(String value) {
        if (value == null) {
            throw new IllegalArgumentException("Post type is required.");
        }
        try {
            return PostType.valueOf(value.toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("Unsupported post type.");
        }
    }

    private User loadUserOrThrow(Long userId) {
        ensureAuthenticated(userId);
        return userRepository.findById(userId)
                .orElseThrow(() -> new EntityNotFoundException("User not found."));
    }

    private void ensureAuthenticated(Long userId) {
        if (userId == null) {
            throw new IllegalArgumentException("Authentication is required.");
        }
    }

    private String resolveDeliveryAddress(String candidate, String fallback) {
        return DEFAULT_DELIVERY_ADDRESS;
    }

}
