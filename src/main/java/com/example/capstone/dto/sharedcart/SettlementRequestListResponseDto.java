package com.example.capstone.dto.sharedcart;

import java.util.List;

public record SettlementRequestListResponseDto(
        List<SettlementRequestResponseDto> requests
) {
    public static SettlementRequestListResponseDto of(List<SettlementRequestResponseDto> requests) {
        return new SettlementRequestListResponseDto(requests);
    }
}
