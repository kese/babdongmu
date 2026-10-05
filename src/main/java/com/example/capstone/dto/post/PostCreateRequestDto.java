package com.example.capstone.dto.post;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
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
@Schema(description = "게시글 생성 요청")
public class PostCreateRequestDto {

    @Schema(description = "모집 유형", example = "delivery", allowableValues = {"delivery", "meet"})
    @NotBlank
    private String postType; // delivery or meet

    @Schema(description = "게시글 제목", example = "야식 같이 주문하실 분")
    @NotBlank
    private String title;

    @Schema(description = "게시글 내용", example = "체크카드 가능하신 분만 참여 부탁드려요.")
    @NotBlank
    private String content;

    @Schema(description = "모집 인원 (작성자 포함)", example = "4")
    @Positive
    private Integer maxParticipants;

    @Schema(description = "모임 시간 (ISO-8601)", example = "2025-04-25T20:00:00")
    private LocalDateTime meetingTime;

    @Schema(description = "모임 장소", example = "서울시 강남구 카페 베이커리")
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

    @Schema(description = "배달 모집 상세 정보")
    @Valid
    private DeliveryDetailDto deliveryDetail;

    @Schema(description = "모임 모집 상세 정보")
    @Valid
    private MeetDetailDto meetDetail;

    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    @Schema(description = "배달 모집 세부 정보")
    public static class DeliveryDetailDto {
        @Schema(description = "주문할 매장명", example = "버거킹 강남점")
        @NotBlank
        private String restaurantName;
        @Schema(description = "매장 주소", example = "서울시 강남구 테헤란로 123")
        private String restaurantAddress;
        @Schema(description = "매장 전화번호", example = "02-123-4567")
        private String restaurantPhone;
        @Schema(description = "배달 받을 주소", example = "서울시 중구 세종대로 110")
        private String deliveryAddress;
        @Schema(description = "배달 장소 위도", example = "37.5665")
        private BigDecimal deliveryLatitude;
        @Schema(description = "배달 장소 경도", example = "126.9780")
        private BigDecimal deliveryLongitude;
        @Schema(description = "총 배달비 (원)", example = "4000")
        @NotNull
        @Positive
        private BigDecimal deliveryFee;
        @Schema(description = "공동 주문 목표 금액 (원)", example = "30000")
        @NotNull
        @Positive
        private BigDecimal targetAmount;
        @Schema(description = "현재까지 모인 금액 (원)", example = "12000")
    @PositiveOrZero
    private BigDecimal currentAmount;
        @Schema(description = "최소 주문 금액 (원)", example = "15000")
    @PositiveOrZero
        private BigDecimal minOrderAmount;
        @Schema(description = "카테고리", example = "치킨")
        private String category;
        @Schema(description = "공유 주문 링크", example = "https://order.example.com/123")
        private String orderLink;
    }

    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    @Schema(description = "모임 모집 세부 정보")
    public static class MeetDetailDto {
        @Schema(description = "만남 장소", example = "서울시 중구 무교동 카페")
        @NotBlank
        private String meetingPlace;
        @Schema(description = "만남 시간 (ISO-8601)", example = "2025-04-25T20:00:00")
        @NotNull
        private LocalDateTime meetingTime;
        @Schema(description = "추가 안내 사항", example = "지각 시 먼저 연락 주세요")
        private String additionalNotes;
    }
}
