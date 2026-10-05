# Capstone Server

밥동무 내부 테스트용 Spring Boot 백엔드 프로토타입입니다. 대외 공개 서비스로 출시하거나 운영한 적은 없으며 현재 배포 서버도 없습니다.

## 실행 조건

서버는 기본적으로 `127.0.0.1:8080`에서만 대기합니다. 시작하려면 격리된 로컬 데이터베이스와 전용 환경 변수를 준비해야 합니다.

- `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`
- `JWT_SECRET` (최소 32바이트)
- 선택 설정: `SERVER_ADDRESS`, `SERVER_PORT`
- Firebase 푸시 사용 시에만 `FIREBASE_ENABLED=true`, `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_PATH` 또는 `FIREBASE_SERVICE_ACCOUNT_BASE64`

저장소에는 데이터베이스 비밀번호, JWT 키, Firebase 서비스 계정 파일이 없습니다. Firebase는 기본 비활성화이며 CORS/WebSocket 기본 허용 출처는 로컬 주소로 제한됩니다.
