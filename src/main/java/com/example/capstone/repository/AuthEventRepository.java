package com.example.capstone.repository;

import com.example.capstone.domain.AuthEvent;
import com.example.capstone.domain.AuthEventType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;

public interface AuthEventRepository extends JpaRepository<AuthEvent, Long> {
    long countByTypeAndSuccessIsTrueAndCreatedAtAfter(AuthEventType type, LocalDateTime after);
    long countByTypeAndSuccessIsFalseAndCreatedAtAfter(AuthEventType type, LocalDateTime after);
    long countBySuccessIsTrueAndCreatedAtAfter(LocalDateTime after);
    List<AuthEvent> findByCreatedAtAfterOrderByCreatedAtDesc(LocalDateTime after, Pageable pageable);
}


