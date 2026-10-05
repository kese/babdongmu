package com.example.capstone.domain.chat;

import java.util.Locale;

public enum ChatRoomStatus {
    // 기존 값들(GATHERING, READY_TO_PAY 등)은 지우거나 @Deprecated 처리하고
    // DB에 새로 넣은 값들과 철자가 100% 똑같아야 합니다.
    
    BEFORE_ORDER,   // 주문 전 (기존 gathering)
    ORDERING,       // 주문 중 (기존 ready_to_pay, ready_to_start)
    DELIVERING,     // 배달 중 (기존 in_progress)
    COMPLETED,      // 완료
    DISPUTED;       // 신고/분쟁
    
    public String toResponseValue() {
        return name().toLowerCase(Locale.ROOT);
    }
}
