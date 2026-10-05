package com.example.capstone.repository;

import com.example.capstone.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmailIgnoreCaseAndDeletedAtIsNull(String email);
    boolean existsByEmailIgnoreCase(String email);
    boolean existsByNickname(String nickname);
    boolean existsByPhoneNumber(String phoneNumber);

    long countByDeletedAtIsNull();
    long countByDeletedAtIsNullAndCreatedAtAfter(LocalDateTime createdAtAfter);
    long countByDeletedAtIsNullAndCreatedAtBetween(LocalDateTime start, LocalDateTime end);
}


