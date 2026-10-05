package com.example.capstone.repository;

import com.example.capstone.domain.notification.FcmToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface FcmTokenRepository extends JpaRepository<FcmToken, Long> {

    Optional<FcmToken> findByToken(String token);

    Optional<FcmToken> findByUser_IdAndDeviceId(Long userId, String deviceId);

    Optional<FcmToken> findByUser_IdAndToken(Long userId, String token);

    void deleteByUser_IdAndToken(Long userId, String token);

    List<FcmToken> findAllByUser_IdIn(Collection<Long> userIds);
}
