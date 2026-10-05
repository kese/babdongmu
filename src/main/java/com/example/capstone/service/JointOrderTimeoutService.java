package com.example.capstone.service;

import com.example.capstone.domain.jointorder.JointOrderRequest;
import com.example.capstone.domain.jointorder.JointOrderStatus;
import com.example.capstone.repository.JointOrderRequestRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class JointOrderTimeoutService {

    private final JointOrderRequestRepository jointOrderRequestRepository;

    /**
     * 10초마다 타임아웃된 합동 주문 요청을 처리합니다.
     */
    @Scheduled(fixedDelay = 10000) // 10초 간격
    @Transactional
    public void processTimeoutRequests() {
        log.debug("Processing timeout requests...");
        
        List<JointOrderRequest> expiredRequests = jointOrderRequestRepository
                .findExpiredRequests(JointOrderStatus.PENDING, LocalDateTime.now());
        
        for (JointOrderRequest request : expiredRequests) {
            if (request.isExpired()) {
                log.info("Processing timeout for request ID: {}", request.getId());
                
                // 타임아웃 상태로 변경
                request.markAsTimeout();
                jointOrderRequestRepository.save(request);
                
                // TODO: FCM 알림 전송 (요청자에게 타임아웃 알림)
                // TODO: 관련 정리 작업 수행
            }
        }
        
        if (!expiredRequests.isEmpty()) {
            log.info("Processed {} timeout requests", expiredRequests.size());
        }
    }
}
