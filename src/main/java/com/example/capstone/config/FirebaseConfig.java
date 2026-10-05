package com.example.capstone.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;

@Slf4j
@Configuration
@RequiredArgsConstructor
public class FirebaseConfig {

    private final FirebaseProperties firebaseProperties;

    @Bean
    @ConditionalOnProperty(prefix = "firebase", name = "enabled", havingValue = "true")
    public FirebaseApp firebaseApp() throws IOException {
        if (!firebaseProperties.isEnabled()) {
            throw new IllegalStateException("firebase.enabled 설정이 true 여야 합니다.");
        }

        return FirebaseApp.getApps().stream()
                .findFirst()
                .orElseGet(this::initializeApp);
    }

    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnProperty(prefix = "firebase", name = "enabled", havingValue = "true")
    public FirebaseMessaging firebaseMessaging(FirebaseApp firebaseApp) {
        return FirebaseMessaging.getInstance(firebaseApp);
    }

    private FirebaseApp initializeApp() {
        try (InputStream credentialsStream = resolveCredentialsStream()) {
            GoogleCredentials credentials = GoogleCredentials.fromStream(credentialsStream);
            FirebaseOptions.Builder builder = FirebaseOptions.builder()
                    .setCredentials(credentials);
            if (StringUtils.hasText(firebaseProperties.getProjectId())) {
                builder.setProjectId(firebaseProperties.getProjectId());
            }
            return FirebaseApp.initializeApp(builder.build());
        } catch (IOException e) {
            throw new IllegalStateException("Firebase 자격 증명을 초기화할 수 없습니다.", e);
        }
    }

    private InputStream resolveCredentialsStream() throws IOException {
        if (StringUtils.hasText(firebaseProperties.getServiceAccountBase64())) {
            byte[] decoded = Base64.getDecoder().decode(firebaseProperties.getServiceAccountBase64());
            return new ByteArrayInputStream(decoded);
        }
        if (StringUtils.hasText(firebaseProperties.getServiceAccountPath())) {
            Path path = Path.of(firebaseProperties.getServiceAccountPath());
            return Files.newInputStream(path);
        }
        throw new IllegalStateException("Firebase 서비스 계정 경로 또는 Base64 값을 설정하세요.");
    }
}
