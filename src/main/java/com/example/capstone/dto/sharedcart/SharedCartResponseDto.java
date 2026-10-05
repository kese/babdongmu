package com.example.capstone.dto.sharedcart;

import com.example.capstone.domain.User;
import com.example.capstone.domain.cart.SharedCart;

import java.time.LocalDateTime;
import java.util.List;

public record SharedCartResponseDto(
        Long id,
        Long roomId,
        Long hostId,
        boolean active,
        LocalDateTime completedAt,
        LocalDateTime createdAt,
        LocalDateTime updatedAt,
        List<SharedCartItemResponseDto> items
) {
    public static SharedCartResponseDto from(SharedCart cart) {
        User host = cart.getHost();
        return new SharedCartResponseDto(
                cart.getId(),
                cart.getChatRoom() != null ? cart.getChatRoom().getId() : null,
                host != null ? host.getId() : null,
                cart.isActive(),
                cart.getCompletedAt(),
                cart.getCreatedAt(),
                cart.getUpdatedAt(),
                cart.getItems().stream()
                        .sorted((a, b) -> {
                            if (a.getCreatedAt() == null && b.getCreatedAt() == null) {
                                return 0;
                            }
                            if (a.getCreatedAt() == null) {
                                return -1;
                            }
                            if (b.getCreatedAt() == null) {
                                return 1;
                            }
                            return a.getCreatedAt().compareTo(b.getCreatedAt());
                        })
                        .map(SharedCartItemResponseDto::from)
                        .toList()
        );
    }

    public static SharedCartResponseDto empty(Long roomId, Long hostId) {
        return new SharedCartResponseDto(
                null,
                roomId,
                hostId,
                false,
                null,
                null,
                null,
                List.of()
        );
    }
}
