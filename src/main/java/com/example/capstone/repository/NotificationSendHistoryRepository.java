package com.example.capstone.repository;

import com.example.capstone.domain.notification.NotificationSendHistory;
import com.example.capstone.domain.notification.NotificationType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface NotificationSendHistoryRepository extends JpaRepository<NotificationSendHistory, Long> {

    boolean existsByNotificationTypeAndReferenceKeyAndUserId(NotificationType notificationType,
                                                             String referenceKey,
                                                             Long userId);

    void deleteByNotificationTypeAndReferenceKeyAndUserId(NotificationType notificationType,
                                                          String referenceKey,
                                                          Long userId);

    /**
     * 사용자의 알림 목록 조회 (최신순)
     */
    List<NotificationSendHistory> findByUserIdOrderByCreatedAtDesc(Long userId);

    /**
     * 사용자의 모든 알림을 읽음 처리
     */
    @Modifying
    @Query("UPDATE NotificationSendHistory n SET n.isRead = true WHERE n.userId = :userId AND n.isRead = false")
    int markAllAsReadByUserId(@Param("userId") Long userId);

    /**
     * 사용자의 특정 알림을 읽음 처리
     */
    @Modifying
    @Query("UPDATE NotificationSendHistory n SET n.isRead = true WHERE n.id = :id AND n.userId = :userId")
    int markAsReadByIdAndUserId(@Param("id") Long id, @Param("userId") Long userId);
}
