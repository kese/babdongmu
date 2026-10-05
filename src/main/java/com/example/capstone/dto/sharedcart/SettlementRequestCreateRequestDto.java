package com.example.capstone.dto.sharedcart;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

public record SettlementRequestCreateRequestDto(
        Long cartId,
        @NotNull(message = "정산 금액은 필수입니다.") @PositiveOrZero(message = "정산 금액은 0 이상이어야 합니다.") Integer amount,
        @PositiveOrZero(message = "배달비 분담 금액은 0 이상이어야 합니다.") Integer deliveryFeeShare,
        String memo
) {
}
