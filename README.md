# 밥동무 캡스톤디자인 프로젝트

밥동무는 주변 사람들과 배달을 함께 주문하거나 식사 모임을 만들기 위한 Flutter 캡스톤디자인 프로젝트입니다. 지도, 모집 게시글, 채팅, 합동 주문 흐름을 구현한 내부 테스트용 앱 프로토타입입니다.

## 프로젝트 상태

- 내부 테스트용 프로토타입으로만 사용했으며, 대외 공개 서비스로 출시하거나 운영한 적이 없습니다.
- 프로젝트는 폐기되었으며 연결 가능한 서버는 운영되지 않습니다.
- 기본 API와 채팅 주소는 예약된 `example.invalid` 도메인이라 기본 설정으로 외부 서비스에 연결되지 않습니다.
- `server` 브랜치에는 별도 Spring Boot 백엔드 구현이 있습니다. 실행 시 데이터베이스와 JWT 비밀값을 환경 변수로 직접 설정해야 합니다.

## 실행 설정

Flutter 앱의 로컬 빌드에서 필요한 값만 명시적으로 전달합니다.

```text
API_BASE_URL=https://your-development-api.example
CHAT_WEBSOCKET_URL=wss://your-development-api.example/ws/websocket
APP_USE_MOCK_DATA=true|false
APP_ENABLE_FIREBASE=true|false
```

실제 서비스용 주소나 키, 계정, 데이터는 저장소에 포함하지 마세요. Firebase는 기본 비활성화되어 있으며, 사용하려면 `APP_ENABLE_FIREBASE=true`와 로컬 `google-services.json` 설정이 필요합니다. Firebase 설정 파일은 저장소에 포함하지 마세요.

Android 네이티브 지도 키는 무제한 키를 넣지 말고 앱 서명과 패키지명으로 제한한 뒤, 무시 처리된 `android/local.properties`에 `MAPS_API_KEY=...`로 설정하세요.

## 개인정보 처리 참고

- 배달 장소 입력에는 상세 주소와 동·호수를 받지 않으며, 게시글에는 장소명과 대략적인 좌표만 사용합니다.
- 인증 토큰, 사용자 ID, 프로필 이름, 푸시 토큰은 앱 프로세스 메모리에만 유지되므로 앱을 다시 열면 재로그인이 필요합니다.
- `integration_test`의 원격 호출은 기본 비활성화되어 있습니다. 격리된 테스트 서버와 일회용 계정을 준비한 뒤 `ENABLE_REMOTE_INTEGRATION_TESTS`, `INTEGRATION_TEST_PASSWORD` 빌드 값을 명시해야 합니다.

## 기술 구성

- Flutter / Dart 모바일 클라이언트
- Spring Boot 백엔드 (`server` 브랜치)
- 지도, 실시간 채팅, 푸시 알림 연동을 실험한 내부 프로토타입
