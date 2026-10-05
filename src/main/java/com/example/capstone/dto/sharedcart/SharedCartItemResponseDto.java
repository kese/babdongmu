package com.example.capstone.dto.sharedcart;

import com.example.capstone.domain.cart.SharedCartItem;
import com.example.capstone.domain.User;

import java.time.LocalDateTime;

public record SharedCartItemResponseDto(
        Long id,
        String name,
        int price,
        Long userId,
        String userNickname,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {
    public static SharedCartItemResponseDto from(SharedCartItem item) {
        User user = item.getUser();
        return new SharedCartItemResponseDto(
                item.getId(),
                item.getName(),
                item.getPrice() != null ? item.getPrice() : 0,
                user != null ? user.getId() : null,
                user != null ? user.getNickname() : null,
                item.getCreatedAt(),
                item.getUpdatedAt()
        );
    }
}
