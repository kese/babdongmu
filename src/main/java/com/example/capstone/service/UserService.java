package com.example.capstone.service;

import com.example.capstone.domain.User;
import com.example.capstone.dto.user.ChangePasswordRequest;
import com.example.capstone.dto.user.ProfileImageResponse;
import com.example.capstone.dto.user.UpdateProfileRequest;
import com.example.capstone.dto.user.UserProfileResponseDto;
import com.example.capstone.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${file.upload-dir:uploads/profile}")
    private String uploadDir;

    @Value("${file.base-url:}")
    private String baseUrl;

    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
            "image/jpeg", "image/jpg", "image/png", "image/gif"
    );
    private static final long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

    @Transactional(readOnly = true)
    public UserProfileResponseDto getProfile(Long userId) {
        User user = loadUserOrThrow(userId);
        return UserProfileResponseDto.from(user);
    }

    @Transactional
    public UserProfileResponseDto updateProfile(Long userId, UpdateProfileRequest request) {
        User user = loadUserOrThrow(userId);

        // 닉네임 중복 체크 (변경하려는 경우에만)
        if (request.getNickname() != null && !request.getNickname().isBlank()) {
            if (!request.getNickname().equals(user.getNickname()) 
                    && userRepository.existsByNickname(request.getNickname())) {
                throw new DataIntegrityViolationException("이미 사용 중인 닉네임입니다.");
            }
            user.updateNickname(request.getNickname());
        }

        // 이메일 중복 체크 (변경하려는 경우에만)
        if (request.getEmail() != null && !request.getEmail().isBlank()) {
            if (!request.getEmail().equalsIgnoreCase(user.getEmail()) 
                    && userRepository.existsByEmailIgnoreCase(request.getEmail())) {
                throw new DataIntegrityViolationException("이미 사용 중인 이메일입니다.");
            }
            user.updateEmail(request.getEmail().toLowerCase());
        }

        // 전화번호 중복 체크 (변경하려는 경우에만)
        if (request.getPhone() != null) {
            String newPhone = request.getPhone().isBlank() ? null : request.getPhone();
            if (newPhone != null && !newPhone.equals(user.getPhoneNumber())
                    && userRepository.existsByPhoneNumber(newPhone)) {
                throw new DataIntegrityViolationException("이미 사용 중인 전화번호입니다.");
            }
            user.updatePhoneNumber(newPhone);
        }

        // 이름 업데이트
        if (request.getName() != null) {
            user.updateUsername(request.getName());
        }

        // 주소 업데이트
        if (request.getAddress() != null) {
            user.updateAddress(request.getAddress());
        }

        // 계좌번호 업데이트
        if (request.getAccount() != null) {
            user.updateAccount(request.getAccount());
        }

        return UserProfileResponseDto.from(user);
    }

    @Transactional
    public void changePassword(Long userId, ChangePasswordRequest request) {
        User user = loadUserOrThrow(userId);

        // 현재 비밀번호 검증
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPasswordHash())) {
            throw new IllegalArgumentException("현재 비밀번호가 일치하지 않습니다.");
        }

        // 새 비밀번호로 업데이트
        user.updatePassword(passwordEncoder.encode(request.getNewPassword()));
    }

    @Transactional
    public ProfileImageResponse uploadProfileImage(Long userId, MultipartFile file) {
        if (userId != null) {
            loadUserOrThrow(userId);
        }

        validateImageFile(file);

        String imageUrl = saveFile(file, userId);

        // 사용자가 로그인한 상태라면 DB 업데이트
        if (userId != null) {
            User user = loadUserOrThrow(userId);
            user.updateProfileImageUrl(imageUrl);
        }

        return new ProfileImageResponse(imageUrl);
    }

    /**
     * 회원가입 시 사용하는 이미지 업로드 (인증 불필요)
     */
    public ProfileImageResponse uploadProfileImageForSignup(MultipartFile file) {
        validateImageFile(file);
        String imageUrl = saveFile(file, null);
        return new ProfileImageResponse(imageUrl);
    }

    @Transactional
    public void deleteAccount(Long userId) {
        User user = loadUserOrThrow(userId);
        user.softDelete();
        log.info("User {} has been soft deleted", userId);
    }

    private void validateImageFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("이미지 파일을 선택해주세요.");
        }

        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("파일 크기는 10MB를 초과할 수 없습니다.");
        }

        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_CONTENT_TYPES.contains(contentType.toLowerCase())) {
            throw new IllegalArgumentException("이미지 파일만 업로드 가능합니다. (JPG, PNG, GIF)");
        }
    }

    private String saveFile(MultipartFile file, Long userId) {
        try {
            // 업로드 디렉토리 생성 (uploads/profile 하위)
            Path uploadPath = Paths.get(uploadDir, "profile");
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }

            // 파일명 생성: userId_timestamp_uuid.ext
            String originalFilename = file.getOriginalFilename();
            String extension = "";
            if (originalFilename != null && originalFilename.contains(".")) {
                extension = originalFilename.substring(originalFilename.lastIndexOf("."));
            }

            String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
            String uniqueId = UUID.randomUUID().toString().substring(0, 8);
            String userPrefix = userId != null ? "user" + userId : "signup";
            String newFilename = userPrefix + "_" + timestamp + "_" + uniqueId + extension;

            // 파일 저장
            Path filePath = uploadPath.resolve(newFilename);
            Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);

            // URL 반환 (Double Slash 방지)
            String relativePath = "/uploads/profile/" + newFilename;
            if (baseUrl != null && !baseUrl.isBlank()) {
                // baseUrl 끝의 슬래시 제거 후 결합
                String cleanBaseUrl = baseUrl.endsWith("/") 
                        ? baseUrl.substring(0, baseUrl.length() - 1) 
                        : baseUrl;
                return cleanBaseUrl + relativePath;
            }
            return relativePath;

        } catch (IOException e) {
            log.error("Failed to save profile image", e);
            throw new RuntimeException("이미지 저장에 실패했습니다.");
        }
    }

    private User loadUserOrThrow(Long userId) {
        if (userId == null) {
            throw new IllegalArgumentException("인증이 필요합니다.");
        }
        return userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> new EntityNotFoundException("사용자를 찾을 수 없습니다."));
    }
}
