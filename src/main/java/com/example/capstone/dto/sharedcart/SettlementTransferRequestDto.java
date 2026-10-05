package com.example.capstone.dto.sharedcart;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.util.List;

public record SettlementTransferRequestDto(
        Long cartId,
        @NotEmpty(message = "정산 대상이 비어 있습니다.") @Valid List<TransferItem> transfers
) {

    public record TransferItem(
            @NotNull(message = "사용자 ID는 필수입니다.") Long userId,
            @NotNull(message = "정산 금액은 필수입니다.") @PositiveOrZero(message = "정산 금액은 0 이상이어야 합니다.") Integer amount,
            @PositiveOrZero(message = "배달비 분담 금액은 0 이상이어야 합니다.") Integer deliveryFeeShare,
            String memo
    ) { }
}
