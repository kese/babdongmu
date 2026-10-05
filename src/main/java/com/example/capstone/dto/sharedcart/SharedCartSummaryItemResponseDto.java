package com.example.capstone.dto.sharedcart;

import com.example.capstone.domain.User;
import com.example.capstone.domain.cart.SharedCartItem;

public record SharedCartSummaryItemResponseDto(
        Long id,
        String name,
        int price,
        Long userId,
        String userNickname
) {
    public static SharedCartSummaryItemResponseDto from(SharedCartItem item) {
        User user = item.getUser();
        return new SharedCartSummaryItemResponseDto(
                item.getId(),
                item.getName(),
                item.getPrice() != null ? item.getPrice() : 0,
                user != null ? user.getId() : null,
                user != null ? user.getNickname() : null
        );
    }
}
