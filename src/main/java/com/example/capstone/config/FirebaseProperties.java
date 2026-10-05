package com.example.capstone.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "firebase")
public class FirebaseProperties {

    /**
     * 기능 활성화 여부. false이면 Firebase 관련 빈을 만들지 않고 FCM 전송을 수행하지 않습니다.
     */
    private boolean enabled = false;

    /**
     * Firebase 프로젝트 ID. Push 알림 전송 시 일부 로깅에서 사용됩니다.
     */
    private String projectId;

    /**
     * 서비스 계정 JSON 파일 경로. 절대경로 또는 classpath: 경로 모두 허용합니다.
     */
    private String serviceAccountPath;

    /**
     * 서비스 계정 JSON 전체 내용을 Base64로 인코딩한 값. 경로 대신 값을 직접 주입할 때 사용합니다.
     */
    private String serviceAccountBase64;
}
