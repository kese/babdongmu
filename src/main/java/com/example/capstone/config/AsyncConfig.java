package com.example.capstone.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;

/**
 * 비동기 작업(FCM 전송 등) 설정
 */
@Slf4j
@Configuration
@EnableAsync
public class AsyncConfig {

    /**
     * FCM 알림 전송용 비동기 Executor
     * - 코어 스레드: 5개
     * - 최대 스레드: 10개
     * - 큐 용량: 100개
     */
    @Bean(name = "fcmExecutor")
    public Executor fcmExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);  // 기본 스레드 수
        executor.setMaxPoolSize(10);  // 최대 스레드 수
        executor.setQueueCapacity(100);  // 대기 큐 크기
        executor.setThreadNamePrefix("fcm-async-");
        
        // 큐가 꽉 찼을 때 처리 방식: 호출한 스레드에서 직접 실행
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(60);
        executor.initialize();
        
        log.info("✅ FCM Async Executor 초기화 완료 (core={}, max={}, queue={})", 
                executor.getCorePoolSize(), 
                executor.getMaxPoolSize(), 
                executor.getQueueCapacity());
        
        return executor;
    }
}
