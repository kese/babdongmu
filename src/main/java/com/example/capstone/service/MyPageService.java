package com.example.capstone.service;

import com.example.capstone.domain.AuthEvent;
import com.example.capstone.domain.AuthEventType;
import com.example.capstone.domain.User;
import com.example.capstone.dto.user.UserDeliveryStatsResponseDto;
import com.example.capstone.dto.user.UserPointsResponseDto;
import com.example.capstone.dto.user.UserProfileResponseDto;
import com.example.capstone.repository.AuthEventRepository;
import com.example.capstone.repository.DeliverySettlementRepository;
import com.example.capstone.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
public class MyPageService {

    private final UserRepository userRepository;
    private final DeliverySettlementRepository deliverySettlementRepository;
    private final AuthEventRepository authEventRepository;

    @Transactional(readOnly = true)
    public UserProfileResponseDto getProfile(Long userId) {
        User user = loadUserOrThrow(userId);
        return UserProfileResponseDto.from(user);
    }

    @Transactional(readOnly = true)
    public UserPointsResponseDto getPoints(Long userId) {
        User user = loadUserOrThrow(userId);
        int points = user.getPoint() != null ? user.getPoint() : 0;
        return UserPointsResponseDto.of(points);
    }

    @Transactional(readOnly = true)
    public UserDeliveryStatsResponseDto getDeliveryStats(Long userId) {
        ensureAuthenticated(userId);
        DeliverySettlementRepository.DeliverySettlementAggregate aggregate =
                deliverySettlementRepository.aggregateByUser(userId);

        if (aggregate == null || aggregate.getTotalOrders() == null || aggregate.getTotalOrders() == 0L) {
            return UserDeliveryStatsResponseDto.empty();
        }

        long totalOrders = aggregate.getTotalOrders();
        long originalFee = toLongCurrency(aggregate.getOriginalDeliveryFee());
        long paidFee = toLongCurrency(aggregate.getPaidDeliveryFee());
        long savedFee = Math.max(0L, toLongCurrency(aggregate.getSavedDeliveryFee()));

        return new UserDeliveryStatsResponseDto(
                totalOrders,
                savedFee,
                paidFee,
                originalFee
        );
    }

    @Transactional
    public void logout(Long userId, String ipAddress, String userAgent) {
        ensureAuthenticated(userId);
        AuthEvent event = AuthEvent.builder()
                .type(AuthEventType.LOGOUT)
                .userId(userId)
                .success(true)
                .ipAddress(ipAddress)
                .userAgent(userAgent)
                .build();
        try {
            authEventRepository.save(event);
        } catch (Exception ignored) {
            // 로그 저장 실패는 로그아웃 응답을 막지 않음
        }
    }

    private User loadUserOrThrow(Long userId) {
        ensureAuthenticated(userId);
        return userRepository.findById(userId)
                .orElseThrow(() -> new EntityNotFoundException("User not found."));
    }

    private void ensureAuthenticated(Long userId) {
        if (userId == null) {
            throw new IllegalArgumentException("Authentication is required.");
        }
    }

    private long toLongCurrency(BigDecimal value) {
        return value != null ? value.longValue() : 0L;
    }
}
