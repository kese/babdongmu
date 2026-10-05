package com.example.capstone.dto.sharedcart;

import java.time.LocalDateTime;
import java.util.List;

public record SettlementTransferResponseDto(
        Long cartId,
        Long roomId,
        LocalDateTime settledAt,
        List<TransferResult> results,
        HostResult host,
        EscrowInfo escrow
) {
    public record TransferResult(
            Long userId,
            String nickname,
            int pointsCharged,
            int updatedPoint
    ) { }

    public record HostResult(
            Long userId,
            String nickname,
            int pointsCredited,
            int updatedPoint
    ) { }

    public record EscrowInfo(
            int targetPoint,
            int totalPoint,
            boolean readyToStart
    ) { }
}
