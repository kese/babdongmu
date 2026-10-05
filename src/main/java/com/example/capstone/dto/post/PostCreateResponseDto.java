package com.example.capstone.dto.post;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Schema(description = "게시글 생성 응답")
public class PostCreateResponseDto {

    @Schema(description = "생성된 게시글 ID", example = "101")
    private final Long postId;
    @Schema(description = "생성된 채팅방 ID", example = "33")
    private final Long chatRoomId;
}
