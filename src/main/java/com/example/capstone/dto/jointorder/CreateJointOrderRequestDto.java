package com.example.capstone.dto.jointorder;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record CreateJointOrderRequestDto(
    @NotNull(message = "요청자 게시글 ID는 필수입니다.")
    @JsonProperty("requester_post_id")
    Long requesterPostId,
    
    @NotEmpty(message = "대상 게시글 ID 목록은 비어있을 수 없습니다.")
    @JsonProperty("target_post_ids")
    List<Long> targetPostIds
) {
}
