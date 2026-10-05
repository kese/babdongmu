package com.example.capstone.dto.post;

import com.example.capstone.domain.post.DeliveryDetail;
import com.example.capstone.domain.post.Post;
import com.example.capstone.domain.post.PostMeetDetail;
import com.example.capstone.util.PublicLocation;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.Locale;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Schema(description = "게시글 목록 조회 응답")
public class PostListResponseDto {

    @Schema(description = "게시글 ID", example = "101")
    private final Long postId;
    @Schema(description = "모집 유형", example = "delivery")
    private final String postType;
    @Schema(description = "게시글 제목", example = "야식 함께 주문해요")
    private final String title;
    @Schema(description = "게시글 상태", example = "active")
    private final String status;
    @Schema(description = "작성자 닉네임", example = "길동이")
    private final String authorNickname;
    @Schema(description = "작성자 프로필 이미지 URL", example = "/uploads/profile/user1_20241130.jpg")
    private final String authorProfileImage;
    @Schema(description = "모집 인원 (작성자 포함)", example = "4")
    private final Integer maxParticipants;
    @Schema(description = "현재 참여 인원", example = "3")
    private final Integer currentParticipants;
    @Schema(description = "모집 완료 여부", example = "false")
    private final boolean recruitmentClosed;
    @Schema(description = "배달 모집일 경우 매장 이름", example = "버거킹 강남점")
    private final String restaurantName;
    @Schema(description = "총 배달비 (원)", example = "4000")
    private final BigDecimal deliveryFee;
    @Schema(description = "1인당 배달비 (원)", example = "1000")
    private final BigDecimal deliveryFeePerPerson;
    @Schema(description = "목표 주문 금액 (원)", example = "30000")
    private final BigDecimal targetAmount;
    @Schema(description = "현재까지 모인 금액 (원)", example = "15000")
    private final BigDecimal currentAmount;
    @Schema(description = "카테고리", example = "치킨")
    private final String category;
    @Schema(description = "배달 장소 (상세 주소 제외)", example = "대략적 위치")
    private final String deliveryAddress;
    @Schema(description = "모임 시간 (ISO-8601)", example = "2025-04-25T20:00:00")
    private final LocalDateTime meetingTime;
    @Schema(description = "모임 장소", example = "서울시 강남구 카페")
    private final String meetingPlace;
    @Schema(description = "장소 ID", example = "12345")
    private final Long placeId;
    @Schema(description = "대략적인 위도 (소수점 셋째 자리까지)", example = "37.567")
    private final BigDecimal locationLatitude;
    @Schema(description = "대략적인 경도 (소수점 셋째 자리까지)", example = "126.978")
    private final BigDecimal locationLongitude;
    @Schema(description = "장소명", example = "강남역 11번 출구")
    private final String locationName;
    @Schema(description = "상세 주소는 응답하지 않음")
    private final String locationAddress;

    public static PostListResponseDto of(Post post, int currentParticipants) {
        DeliveryDetail detail = post.getDeliveryDetail();
        PostMeetDetail meetDetail = post.getMeetDetail();
        BigDecimal deliveryFee = detail != null ? detail.getDeliveryFee() : null;
        BigDecimal perPerson = calculatePerPersonFee(deliveryFee, post.getMaxParticipants());
        return PostListResponseDto.builder()
                .postId(post.getId())
                .postType(post.getPostType() != null ? post.getPostType().name().toLowerCase(Locale.ROOT) : null)
                .title(post.getTitle())
                .status(post.getStatus() != null ? post.getStatus().name().toLowerCase(Locale.ROOT) : null)
                .authorNickname(post.getAuthor() != null ? post.getAuthor().getNickname() : null)
                .authorProfileImage(post.getAuthor() != null ? post.getAuthor().getProfileImageUrl() : null)
                .maxParticipants(post.getMaxParticipants())
                .currentParticipants(currentParticipants)
                .recruitmentClosed(isRecruitmentClosed(post.getMaxParticipants(), currentParticipants))
                .restaurantName(detail != null ? detail.getRestaurantName() : null)
                .deliveryFee(deliveryFee)
                .deliveryFeePerPerson(perPerson)
                .targetAmount(detail != null ? detail.getTargetAmount() : null)
                .currentAmount(detail != null ? detail.getCurrentAmount() : null)
                .category(detail != null ? detail.getCategory() : null)
                .deliveryAddress(null)
                .meetingTime(meetDetail != null ? meetDetail.getMeetingTime() : post.getMeetingTime())
                .meetingPlace(post.getPostType() == com.example.capstone.domain.post.PostType.DELIVERY
                        ? PublicLocation.safeLabel(post.getLocationName())
                        : (meetDetail != null ? meetDetail.getMeetingPlace() : post.getMeetingPlace()))
                .placeId(post.getPlaceId())
                .locationLatitude(PublicLocation.approximateCoordinate(post.getLocationLatitude()))
                .locationLongitude(PublicLocation.approximateCoordinate(post.getLocationLongitude()))
                .locationName(post.getPostType() == com.example.capstone.domain.post.PostType.DELIVERY
                        ? PublicLocation.safeLabel(post.getLocationName())
                        : post.getLocationName())
                .locationAddress(null)
                .build();
    }

    private static BigDecimal calculatePerPersonFee(BigDecimal deliveryFee, Integer maxParticipants) {
        if (deliveryFee == null || maxParticipants == null || maxParticipants <= 0) {
            return null;
        }
        return deliveryFee.divide(BigDecimal.valueOf(maxParticipants), 0, RoundingMode.DOWN);
    }

    private static boolean isRecruitmentClosed(Integer maxParticipants, int participantCount) {
        if (maxParticipants == null || maxParticipants <= 0) {
            return false;
        }
        return participantCount >= maxParticipants;
    }
}
