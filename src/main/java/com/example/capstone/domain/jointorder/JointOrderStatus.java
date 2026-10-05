package com.example.capstone.domain.jointorder;

public enum JointOrderStatus {
    PENDING,    // 응답 대기 중
    ACCEPTED,   // 모두 수락 (매칭 성공)
    REJECTED,   // 일부 거절 (매칭 실패)
    TIMEOUT;    // 타임아웃 (일부 미응답)
}
