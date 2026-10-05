package com.example.capstone.repository;

import com.example.capstone.domain.settlement.SettlementRequest;
import com.example.capstone.domain.settlement.SettlementRequestStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SettlementRequestRepository extends JpaRepository<SettlementRequest, Long> {

    Optional<SettlementRequest> findByIdAndCart_ChatRoom_Id(Long id, Long roomId);

    boolean existsByCart_IdAndRequester_IdAndStatus(Long cartId, Long requesterId, SettlementRequestStatus status);

    List<SettlementRequest> findByCart_IdAndStatus(Long cartId, SettlementRequestStatus status);

    List<SettlementRequest> findByCart_IdOrderByRequestedAtAsc(Long cartId);

    List<SettlementRequest> findByCart_IdAndRequester_IdOrderByRequestedAtDesc(Long cartId, Long requesterId);
}
