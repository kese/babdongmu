package com.example.capstone.dto.sharedcart;

import com.example.capstone.domain.settlement.SettlementRequest;
import com.example.capstone.domain.settlement.SettlementRequestStatus;

import java.time.LocalDateTime;

public record SettlementRequestResponseDto(
        Long requestId,
        Long cartId,
        Long roomId,
        Long requesterId,
        String requesterNickname,
        int amount,
        Integer deliveryFeeShare,
        String memo,
        SettlementRequestStatus status,
        LocalDateTime requestedAt,
        LocalDateTime processedAt,
        Long processedBy,
        String decisionMemo
) {

    public static SettlementRequestResponseDto from(SettlementRequest request) {
        Long cartId = request.getCart() != null ? request.getCart().getId() : null;
        Long roomId = (request.getCart() != null && request.getCart().getChatRoom() != null)
                ? request.getCart().getChatRoom().getId() : null;
        Long processedBy = request.getProcessedBy() != null ? request.getProcessedBy().getId() : null;
        String requesterNickname = request.getRequester() != null ? request.getRequester().getNickname() : null;
        return new SettlementRequestResponseDto(
                request.getId(),
                cartId,
                roomId,
                request.getRequester() != null ? request.getRequester().getId() : null,
                requesterNickname,
                request.getAmount() != null ? request.getAmount() : 0,
                request.getDeliveryFeeShare(),
                request.getMemo(),
                request.getStatus(),
                request.getRequestedAt(),
                request.getProcessedAt(),
                                processedBy,
                                request.getDecisionMemo()
        );
    }
}
