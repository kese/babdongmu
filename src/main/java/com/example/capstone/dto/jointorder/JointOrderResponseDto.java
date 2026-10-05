package com.example.capstone.dto.jointorder;

import java.time.LocalDateTime;

public record JointOrderResponseDto(
    Long postId,
    String responderName,
    Boolean accepted,
    LocalDateTime responseTime
) {
    
    // 응답 결과용 생성자
    public JointOrderResponseDto(Boolean accepted, String message) {
        this(null, null, accepted, null);
    }
}
