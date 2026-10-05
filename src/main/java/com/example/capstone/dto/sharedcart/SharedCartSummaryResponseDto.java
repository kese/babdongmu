package com.example.capstone.dto.sharedcart;

import com.example.capstone.domain.cart.SharedCart;
import com.example.capstone.domain.chat.ChatRoom;
import com.example.capstone.domain.post.DeliveryDetail;
import com.example.capstone.domain.post.Post;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;

public record SharedCartSummaryResponseDto(
        Long cartId,
        Long roomId,
        Long hostId,
        String hostNickname,
        List<SharedCartSummaryItemResponseDto> items,
        int totalMenuPrice,
        Integer deliveryFee,
        Integer deliveryFeePerPerson,
        int totalPrice,
        String receiptStatus,
        LocalDateTime createdAt,
        LocalDateTime finalizedAt
) {
    public static SharedCartSummaryResponseDto pending(SharedCart cart,
                                                       ChatRoom chatRoom,
                                                       Integer deliveryFee,
                                                       Integer deliveryFeePerPerson) {
        return build(cart, chatRoom, deliveryFee, deliveryFeePerPerson, "pending_settlement", null);
    }

    public static SharedCartSummaryResponseDto finalized(SharedCart cart,
                                                         ChatRoom chatRoom,
                                                         Integer deliveryFee,
                                                         Integer deliveryFeePerPerson,
                                                         LocalDateTime finalizedAt) {
        return build(cart, chatRoom, deliveryFee, deliveryFeePerPerson, "finalized", finalizedAt);
    }

    private static SharedCartSummaryResponseDto build(SharedCart cart,
                                                      ChatRoom chatRoom,
                                                      Integer deliveryFee,
                                                      Integer deliveryFeePerPerson,
                                                      String receiptStatus,
                                                      LocalDateTime finalizedAt) {
        Objects.requireNonNull(cart, "cart must not be null");
        List<SharedCartSummaryItemResponseDto> summaryItems = cart.getItems().stream()
                .map(SharedCartSummaryItemResponseDto::from)
                .toList();
        int totalMenuPrice = summaryItems.stream()
                .mapToInt(SharedCartSummaryItemResponseDto::price)
                .sum();
        int resolvedDeliveryFee = deliveryFee != null ? deliveryFee : 0;
        int totalPrice = totalMenuPrice + resolvedDeliveryFee;
        Long hostId = cart.getHost() != null ? cart.getHost().getId() : null;
        String hostNickname = cart.getHost() != null ? cart.getHost().getNickname() : null;
        Long roomId = chatRoom != null ? chatRoom.getId() : null;
        return new SharedCartSummaryResponseDto(
                cart.getId(),
                roomId,
                hostId,
                hostNickname,
                summaryItems,
                totalMenuPrice,
                deliveryFee,
                deliveryFeePerPerson,
                totalPrice,
                receiptStatus,
                cart.getCreatedAt(),
                finalizedAt
        );
    }

    public static Integer resolveDeliveryFee(Post post) {
        if (post == null) {
            return null;
        }
        DeliveryDetail detail = post.getDeliveryDetail();
        if (detail == null || detail.getDeliveryFee() == null) {
            return null;
        }
        BigDecimal fee = detail.getDeliveryFee();
        return fee == null ? null : fee.setScale(0, RoundingMode.HALF_UP).intValue();
    }
}
