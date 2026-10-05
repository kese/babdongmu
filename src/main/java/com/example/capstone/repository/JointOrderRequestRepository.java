package com.example.capstone.repository;

import com.example.capstone.domain.jointorder.JointOrderRequest;
import com.example.capstone.domain.jointorder.JointOrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface JointOrderRequestRepository extends JpaRepository<JointOrderRequest, Long> {

    // 요청자의 대기 중인 요청 조회
    @Query("SELECT jor FROM JointOrderRequest jor WHERE jor.requester.id = :userId AND jor.status = :status")
    List<JointOrderRequest> findByRequesterIdAndStatus(@Param("userId") Long userId, @Param("status") JointOrderStatus status);

    // 대상자에게 온 대기 중인 요청 조회
    @Query("SELECT DISTINCT jor FROM JointOrderRequest jor " +
           "JOIN jor.targets jot " +
           "JOIN jot.targetPost p " +
           "WHERE p.author.id = :userId AND jor.status = :status")
    List<JointOrderRequest> findPendingRequestsForUser(@Param("userId") Long userId, @Param("status") JointOrderStatus status);

    // 타임아웃된 요청 조회
    @Query("SELECT jor FROM JointOrderRequest jor WHERE jor.status = :status AND jor.timeoutAt < :now")
    List<JointOrderRequest> findExpiredRequests(@Param("status") JointOrderStatus status, @Param("now") LocalDateTime now);

    // 게시글별 대기 중인 요청 조회 (중복 요청 방지용)
    @Query("SELECT jor FROM JointOrderRequest jor " +
           "JOIN jor.targets jot " +
           "WHERE jot.targetPost.id = :postId AND jor.status = :status")
    List<JointOrderRequest> findPendingRequestsForPost(@Param("postId") Long postId, @Param("status") JointOrderStatus status);

    // 요청 ID로 상세 조회 (targets만 fetch)
    @Query("SELECT jor FROM JointOrderRequest jor " +
           "LEFT JOIN FETCH jor.targets " +
           "WHERE jor.id = :requestId")
    Optional<JointOrderRequest> findByIdWithDetails(@Param("requestId") Long requestId);
}
