package com.example.capstone.dto.post;

import com.example.capstone.domain.post.Post;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class JoinResponseDto {

    private final Long postId;
    private final Long userId;
    private final Integer currentParticipants;
    private final Integer maxParticipants;
    private final Integer remainingSlots;
    private final boolean success;

    public static JoinResponseDto of(Post post, Long userId, int currentParticipants) {
        Integer max = post.getMaxParticipants();
        Integer remaining = null;
        if (max != null) {
            remaining = Math.max(0, max - currentParticipants);
        }
        return JoinResponseDto.builder()
                .postId(post.getId())
                .userId(userId)
                .currentParticipants(currentParticipants)
                .maxParticipants(max)
                .remainingSlots(remaining)
                .success(true)
                .build();
    }
}
