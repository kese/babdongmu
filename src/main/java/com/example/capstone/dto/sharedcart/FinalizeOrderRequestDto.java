package com.example.capstone.dto.sharedcart;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record FinalizeOrderRequestDto(
        @NotNull Long cartId,
        @NotEmpty List<Long> targetParticipantIds,
        Integer expectedTotalPoint,
        String memo
) {
}
