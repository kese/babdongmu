package com.example.capstone.dto.chat;

import com.example.capstone.domain.User;
import com.example.capstone.domain.chat.ChatRoom;
import com.example.capstone.domain.chat.ChatRoomParticipant;
import com.example.capstone.domain.chat.ChatRoomStatus;
import com.example.capstone.domain.post.Post;

import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

public record ChatRoomBasicInfoResponseDto(
        Long roomId,
        Long postId,
        Long hostId,
        String roomStatus,
        Integer maxCapacity,
        Integer escrowTargetPoint,
        Integer escrowTotalPoint,
        Integer targetCount,
        Integer confirmedCount,
        List<TargetParticipantDto> targetParticipants
) {
    public static ChatRoomBasicInfoResponseDto from(ChatRoom chatRoom, List<ChatRoomParticipant> targets) {
        Post post = chatRoom.getPost();
        User host = post != null ? post.getAuthor() : null;
        ChatRoomStatus status = chatRoom.getRoomStatus();
        List<TargetParticipantDto> targetDtos = targets == null ? List.of() : targets.stream()
                .filter(Objects::nonNull)
                .map(TargetParticipantDto::from)
                .collect(Collectors.toList());
        int targetCount = targetDtos.size();
        int confirmedCount = (int) targetDtos.stream()
                .filter(dto -> Boolean.TRUE.equals(dto.hasConfirmedReception()))
                .count();
        return new ChatRoomBasicInfoResponseDto(
                chatRoom.getId(),
                post != null ? post.getId() : null,
                host != null ? host.getId() : null,
                status != null ? status.toResponseValue() : null,
                chatRoom.getMaxCapacity(),
                chatRoom.getEscrowTargetPoint(),
                chatRoom.getEscrowTotalPoint(),
                targetCount,
                confirmedCount,
                targetDtos
        );
    }

    public record TargetParticipantDto(
            Long userId,
            String nickname,
            Boolean hasConfirmedReception,
                        Boolean hasReportedIssue,
                        Boolean hasAcceptedDeliveryGuide
    ) {
        private static TargetParticipantDto from(ChatRoomParticipant participant) {
            User user = participant.getUser();
            return new TargetParticipantDto(
                    user != null ? user.getId() : null,
                    user != null ? user.getNickname() : null,
                    participant.getConfirmedReception(),
                                        participant.getReportedIssue(),
                                        participant.getHasAcceptedDeliveryGuide()
            );
        }
    }
}
