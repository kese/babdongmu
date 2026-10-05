package com.example.capstone.service;

import com.example.capstone.domain.User;
import com.example.capstone.domain.AuthEvent;
import com.example.capstone.domain.AuthEventType;
import com.example.capstone.dto.LoginRequest;
import com.example.capstone.dto.SignupRequest;
import com.example.capstone.dto.TokenResponseDto;
import com.example.capstone.dto.UserResponse;
import com.example.capstone.repository.UserRepository;
import com.example.capstone.repository.AuthEventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.capstone.security.JwtTokenProvider;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final AuthEventRepository authEventRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    @Transactional
    public UserResponse signup(SignupRequest request) {
        String emailNormalized = request.getEmail().toLowerCase(Locale.ROOT);

    if (userRepository.existsByEmailIgnoreCase(emailNormalized)) {
            throw new DataIntegrityViolationException("이미 사용 중인 이메일입니다.");
        }
        if (request.getNickname() != null && userRepository.existsByNickname(request.getNickname())) {
            throw new DataIntegrityViolationException("이미 사용 중인 닉네임입니다.");
        }
        if (request.getPhoneNumber() != null && !request.getPhoneNumber().isBlank()
                && userRepository.existsByPhoneNumber(request.getPhoneNumber())) {
            throw new DataIntegrityViolationException("이미 사용 중인 전화번호입니다.");
        }

        User user = User.builder()
                .email(emailNormalized)
        .passwordHash(passwordEncoder.encode(request.getPassword()))
        .username(request.getUsername())
                .phoneNumber(emptyToNull(request.getPhoneNumber()))
                .profileImageUrl(request.getProfileImageUrl())
                .nickname(request.getNickname())
        .locationLatitude(request.getLocationLatitude())
        .locationLongitude(request.getLocationLongitude())
        .isActive(Boolean.TRUE)
        .point(0)
                .build();

        User saved = userRepository.save(user);
        return UserResponse.from(saved);
    }

    @Transactional
    public TokenResponseDto login(LoginRequest request) {
        String emailNormalized = request.getEmail().toLowerCase(Locale.ROOT);
        User user = userRepository.findByEmailIgnoreCaseAndDeletedAtIsNull(emailNormalized)
                .orElseGet(() -> {
            safeSaveAuthEvent(AuthEvent.builder()
                .type(AuthEventType.FAILED_LOGIN)
                .email(emailNormalized)
                .success(false)
                .reason("USER_NOT_FOUND")
                .build());
                    throw new IllegalArgumentException("이메일 또는 비밀번호가 올바르지 않습니다.");
                });

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            safeSaveAuthEvent(AuthEvent.builder()
            .type(AuthEventType.FAILED_LOGIN)
                    .email(emailNormalized)
                    .userId(user.getId())
                    .success(false)
                    .reason("WRONG_PASSWORD")
                    .build());
            throw new IllegalArgumentException("이메일 또는 비밀번호가 올바르지 않습니다.");
        }

        safeSaveAuthEvent(AuthEvent.builder()
                .type(AuthEventType.LOGIN)
                .email(emailNormalized)
                .userId(user.getId())
                .success(true)
                .build());
        String accessToken = jwtTokenProvider.generateToken(user.getId());
        return new TokenResponseDto(accessToken);
    }

    private String emptyToNull(String value) {
        return (value == null || value.isBlank()) ? null : value;
    }

    private void safeSaveAuthEvent(AuthEvent event) {
        try {
            authEventRepository.save(event);
        } catch (Exception ignored) {
            // 모니터링 로깅 실패는 인증 흐름을 막지 않음
        }
    }
}


