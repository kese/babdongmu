package com.example.capstone.dto.post;

import com.example.capstone.domain.post.DeliveryDetail;
import com.example.capstone.domain.post.Post;
import com.example.capstone.domain.post.PostMeetDetail;
import com.example.capstone.domain.post.PostParticipant;
import com.example.capstone.domain.post.ParticipantRole;
import com.example.capstone.util.PublicLocation;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

@Getter
@Builder
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Schema(description = "게시글 상세 조회 응답")
public class PostDetailResponseDto {

    @Schema(description = "게시글 ID", example = "101")
    private final Long postId;
    @Schema(description = "모집 유형", example = "delivery")
    private final String postType;
    @Schema(description = "게시글 제목", example = "야식 함께 주문해요")
    private final String title;
    @Schema(description = "게시글 본문", example = "체크카드 가능하신 분 환영합니다")
    private final String content;
    @Schema(description = "게시글 상태", example = "active")
    private final String status;
    @Schema(description = "작성자 닉네임", example = "길동이")
    private final String authorNickname;
    @Schema(description = "작성자 프로필 이미지 URL", example = "/uploads/profile/user1_20241130.jpg")
    private final String authorProfileImage;
    @Schema(description = "모집 인원", example = "4")
    private final Integer maxParticipants;
    @Schema(description = "현재 참여 인원", example = "3")
    private final Integer currentParticipants;
    @Schema(description = "배달 모집일 경우 매장명", example = "버거킹 강남점")
    private final String restaurantName;
    @Schema(description = "총 배달비 (원)", example = "4000")
    private final BigDecimal deliveryFee;
    @Schema(description = "1인당 배달비 (원)", example = "1000")
    private final BigDecimal deliveryFeePerPerson;
    @Schema(description = "목표 주문 금액 (원)", example = "30000")
    private final BigDecimal targetAmount;
    @Schema(description = "현재까지 모인 금액 (원)", example = "15000")
    private final BigDecimal currentAmount;
    @Schema(description = "최소 주문 금액 (원)", example = "15000")
    private final BigDecimal minOrderAmount;
    @Schema(description = "카테고리", example = "치킨")
    private final String category;
    @Schema(description = "주문 링크", example = "https://order.example.com/123")
    private final String orderLink;
    @Schema(description = "매장 주소", example = "서울시 강남구 테헤란로 123")
    private final String restaurantAddress;
    @Schema(description = "매장 전화번호", example = "02-123-4567")
    private final String restaurantPhone;
    @Schema(description = "상세 배달 주소는 응답하지 않음")
    private final String deliveryAddress;
    @Schema(description = "모임 시간 (ISO-8601)", example = "2025-04-25T20:00:00")
    private final LocalDateTime meetingTime;
    @Schema(description = "모임 장소", example = "서울시 강남구 카페")
    private final String meetingPlace;
    @Schema(description = "참여자 목록")
    private final List<Participant> participants;

    public static PostDetailResponseDto of(Post post, int currentParticipants, List<PostParticipant> participantEntities) {
        DeliveryDetail detail = post.getDeliveryDetail();
        PostMeetDetail meetDetail = post.getMeetDetail();
        BigDecimal deliveryFee = detail != null ? detail.getDeliveryFee() : null;
        BigDecimal perPerson = calculatePerPersonFee(deliveryFee, post.getMaxParticipants());
        List<Participant> participantDtos = participantEntities.stream()
                .map(pp -> Participant.builder()
                        .userId(pp.getUser() != null ? pp.getUser().getId() : null)
                        .nickname(pp.getUser() != null ? pp.getUser().getNickname() : null)
                        .profileImage(pp.getUser() != null ? pp.getUser().getProfileImageUrl() : null)
                        .role(pp.getRole() != null ? pp.getRole().name().toLowerCase(Locale.ROOT) : ParticipantRole.MEMBER.name().toLowerCase(Locale.ROOT))
            .paymentStatus(pp.getPaymentStatus() != null ? pp.getPaymentStatus().toResponseValue() : null)
                        .joinedAt(pp.getJoinedAt())
                        .build())
                .collect(Collectors.toList());

        return PostDetailResponseDto.builder()
                .postId(post.getId())
                .postType(post.getPostType() != null ? post.getPostType().name().toLowerCase(Locale.ROOT) : null)
                .title(post.getTitle())
                .content(post.getContent())
                .status(post.getStatus() != null ? post.getStatus().name().toLowerCase(Locale.ROOT) : null)
                .authorNickname(post.getAuthor() != null ? post.getAuthor().getNickname() : null)
                .authorProfileImage(post.getAuthor() != null ? post.getAuthor().getProfileImageUrl() : null)
                .maxParticipants(post.getMaxParticipants())
                .currentParticipants(currentParticipants)
                .restaurantName(detail != null ? detail.getRestaurantName() : null)
                .deliveryFee(deliveryFee)
                .deliveryFeePerPerson(perPerson)
                .targetAmount(detail != null ? detail.getTargetAmount() : null)
                .currentAmount(detail != null ? detail.getCurrentAmount() : null)
                .minOrderAmount(detail != null ? detail.getMinOrderAmount() : null)
                .category(detail != null ? detail.getCategory() : null)
                .orderLink(detail != null ? detail.getOrderLink() : null)
                .restaurantAddress(detail != null ? detail.getRestaurantAddress() : null)
                .restaurantPhone(detail != null ? detail.getRestaurantPhone() : null)
                .deliveryAddress(null)
                .meetingTime(meetDetail != null ? meetDetail.getMeetingTime() : post.getMeetingTime())
                .meetingPlace(post.getPostType() == com.example.capstone.domain.post.PostType.DELIVERY
                        ? PublicLocation.safeLabel(post.getLocationName())
                        : (meetDetail != null ? meetDetail.getMeetingPlace() : post.getMeetingPlace()))
                .participants(participantDtos)
                .build();
    }

    private static BigDecimal calculatePerPersonFee(BigDecimal deliveryFee, Integer maxParticipants) {
        if (deliveryFee == null || maxParticipants == null || maxParticipants <= 0) {
            return null;
        }
        return deliveryFee.divide(BigDecimal.valueOf(maxParticipants), 0, RoundingMode.DOWN);
    }

    @Getter
    @Builder
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    @Schema(description = "게시글 참여자 정보")
    public static class Participant {
        @Schema(description = "참여자 사용자 ID", example = "12")
        private final Long userId;
        @Schema(description = "참여자 닉네임", example = "studyMaster")
        private final String nickname;
        @Schema(description = "참여자 프로필 이미지 URL", example = "/uploads/profile/user12_20241130.jpg")
        private final String profileImage;
        @Schema(description = "참여자 역할 (creator/member)", example = "creator")
        private final String role;
        @Schema(description = "결제 상태", example = "pending")
        private final String paymentStatus;
        @Schema(description = "참여 일시 (ISO-8601)", example = "2025-04-20T21:05:00")
        private final LocalDateTime joinedAt;
    }
}
