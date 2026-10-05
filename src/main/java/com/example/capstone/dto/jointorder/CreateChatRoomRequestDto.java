package com.example.capstone.dto.jointorder;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record CreateChatRoomRequestDto(
    @NotNull(message = "요청 ID는 필수입니다.")
    Long requestId,
    
    @NotEmpty(message = "게시글 ID 목록은 비어있을 수 없습니다.")
    List<Long> postIds
) {
}
