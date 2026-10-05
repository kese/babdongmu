package com.example.capstone.dto.jointorder;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;

public record RespondToRequestDto(
    @NotNull(message = "게시글 ID는 필수입니다.")
    @JsonProperty("post_id")
    Long postId,
    
    @NotNull(message = "수락 여부는 필수입니다.")
    Boolean accepted
) {
}
