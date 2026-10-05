package com.example.capstone.dto.post;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Schema(description = "게시글 수정 요청")
public class PostUpdateRequestDto {

    @Schema(description = "수정할 게시글 제목", example = "토요일 야식 모집")
    @NotBlank
    private String title;

    @Schema(description = "수정할 게시글 내용", example = "참여자 한 명 더 구합니다.")
    @NotBlank
    private String content;

    @Schema(description = "모집 인원 (작성자 포함)", example = "5")
    private Integer maxParticipants;

    @Schema(description = "모임 시간 (ISO-8601)", example = "2025-05-01T19:30:00")
    private LocalDateTime meetingTime;

    @Schema(description = "모임 장소", example = "을지로 입구 카페")
    private String meetingPlace;

    @Schema(description = "장소 ID", example = "12345")
    private Long placeId;

    @Schema(description = "위도", example = "37.5665")
    private BigDecimal locationLatitude;

    @Schema(description = "경도", example = "126.9780")
    private BigDecimal locationLongitude;

    @Schema(description = "장소명", example = "강남역 11번 출구")
    private String locationName;

    @Schema(description = "장소 주소", example = "서울 강남구 테헤란로 123")
    private String locationAddress;

    @Schema(description = "배달 모집 세부 정보")
    @Valid
    private PostCreateRequestDto.DeliveryDetailDto deliveryDetail;

    @Schema(description = "모임 모집 세부 정보")
    @Valid
    private PostCreateRequestDto.MeetDetailDto meetDetail;
}
