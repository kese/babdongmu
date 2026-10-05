package com.example.capstone.dto.chat;

import com.example.capstone.util.PublicLocation;

import com.example.capstone.domain.chat.ChatMessage;
import com.example.capstone.domain.chat.ChatRoom;
import com.example.capstone.domain.chat.ChatRoomParticipant;
import com.example.capstone.domain.chat.ChatRoomStatus;
import com.example.capstone.domain.post.Post;
import com.example.capstone.domain.post.PostStatus;
import com.example.capstone.domain.post.DeliveryDetail;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.Locale;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class ChatRoomListResponseDto {

    private final Long roomId;
    private final String roomName;
    private final String roomType;
    private final Long postId;
    private final String postTitle;
    private final String postType;
    private final Integer maxParticipants;
    private final Integer currentParticipants;
    private final String lastMessage;
    private final LocalDateTime lastMessageAt;
    private final Long unreadCount;
    private final Integer memberCount;
    private final Boolean hasUnread;
    private final String status;
    private final String location;
    private final String restaurantName;

    public static ChatRoomListResponseDto of(ChatRoomParticipant participation,
                                             ChatMessage lastMessage,
                                             long unreadCount,
                                             int memberCount) {
        ChatRoom room = participation.getChatRoom();
        Post post = room.getPost();
    Integer maxParticipants = post != null ? post.getMaxParticipants() : null;
    int currentParticipants = resolveCurrentParticipants(post, memberCount);
        String status = deriveStatus(room, post, currentParticipants, maxParticipants);
        return ChatRoomListResponseDto.builder()
                .roomId(room.getId())
                .roomName(room.getRoomName())
                .roomType(room.getRoomType() != null ? room.getRoomType().toResponseValue() : null)
                .postId(post != null ? post.getId() : null)
                .postTitle(post != null ? post.getTitle() : null)
                .postType(post != null && post.getPostType() != null ? post.getPostType().name().toLowerCase(Locale.ROOT) : null)
                .maxParticipants(maxParticipants)
                .currentParticipants(currentParticipants)
                .lastMessage(lastMessage != null ? lastMessage.getMessageContent() : null)
                .lastMessageAt(lastMessage != null ? lastMessage.getSentAt() : null)
                .unreadCount(unreadCount)
                .memberCount(memberCount)
                .hasUnread(unreadCount > 0 ? Boolean.TRUE : Boolean.FALSE)
                .status(status)
                .location(resolveLocation(post))
                .restaurantName(resolveRestaurantName(post))
                .build();
    }

    private static String deriveStatus(ChatRoom room, Post post, int currentParticipants, Integer maxParticipants) {
        if (room == null) {
            return null;
        }
        ChatRoomStatus roomStatus = room.getRoomStatus();
        if (roomStatus != null) {
            if (roomStatus == ChatRoomStatus.BEFORE_ORDER && post != null && post.getStatus() != null) {
                return post.getStatus().toResponseValue();
            }
            return roomStatus.toResponseValue();
        }
        if (post != null) {
            if (Boolean.FALSE.equals(room.getActive())) {
                return room.getRoomType() != null ? room.getRoomType().toResponseValue() : null;
            }
            PostStatus postStatus = post.getStatus();
            if (postStatus == null) {
                return room.getRoomType() != null ? room.getRoomType().toResponseValue() : null;
            }
            if (PostStatus.ACTIVE.equals(postStatus) && maxParticipants != null && maxParticipants > 0 && currentParticipants >= maxParticipants) {
                return "closed";
            }
            return postStatus.toResponseValue();
        }
        return room.getRoomType() != null ? room.getRoomType().toResponseValue() : null;
    }

    private static int resolveCurrentParticipants(Post post, int memberCount) {
        if (post == null) {
            return memberCount;
        }
        Integer postCurrent = post.getCurrentParticipants();
        if (postCurrent != null && postCurrent > 0) {
            return postCurrent;
        }
        return memberCount;
    }

    private static String resolveLocation(Post post) {
        if (post == null) {
            return null;
        }
        if (post.getPostType() == com.example.capstone.domain.post.PostType.DELIVERY) {
            return PublicLocation.safeLabel(post.getLocationName());
        }
        if (post.getMeetingPlace() != null && !post.getMeetingPlace().isBlank()) {
            return post.getMeetingPlace();
        }
        return null;
    }

    private static String resolveRestaurantName(Post post) {
        if (post == null) {
            return null;
        }
        DeliveryDetail deliveryDetail = post.getDeliveryDetail();
        if (deliveryDetail != null && deliveryDetail.getRestaurantName() != null && !deliveryDetail.getRestaurantName().isBlank()) {
            return deliveryDetail.getRestaurantName();
        }
        return null;
    }
}
