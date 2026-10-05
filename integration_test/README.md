# 통합 테스트 (Integration Test)

## 개요

통합 테스트는 실제 앱을 실행합니다. 원격 API 호출은 기본적으로 비활성화되어 있습니다.

## 실행 방법

### 1. 의존성 설치
```bash
flutter pub get
```

### 2. 디바이스 준비
- Android 에뮬레이터 실행 또는 실제 기기 연결
- 또는 Chrome 브라우저 (웹)

### 3. 통합 테스트 실행

#### Android 디바이스/에뮬레이터
```bash
flutter test integration_test/app_test.dart
```

또는

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart
```

#### Chrome 브라우저 (웹)
```bash
flutter test integration_test/app_test.dart -d chrome
```

## 테스트 작성 가이드

### 기본 구조
```dart
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('테스트 이름', (WidgetTester tester) async {
    // 앱 시작
    app.main();
    await tester.pumpAndSettle();
    
    // 테스트 코드 작성
  });
}
```

### 주요 차이점

| 항목 | 유닛/위젯 테스트 | 통합 테스트 |
|------|----------------|------------|
| 앱 실행 | ❌ | ✅ 실제 앱 실행 |
| 서버 API 호출 | ❌ 차단됨 | ✅ 실제 호출 |
| 네이티브 플러그인 | ❌ Mock 필요 | ✅ 실제 동작 |
| 실행 시간 | 빠름 | 느림 |
| 사용 용도 | 로직 검증 | 전체 플로우 검증 |

## 주의사항

1. **원격 테스트는 명시적으로 활성화해야 함**
   - 기본 설정은 예약된 `example.invalid` 주소를 사용하며 실제 서버를 호출하지 않습니다.
   - 격리된 테스트 서버에 한해 `API_BASE_URL`, `CHAT_WEBSOCKET_URL`, `ENABLE_REMOTE_INTEGRATION_TESTS=true`, `INTEGRATION_TEST_PASSWORD`를 빌드 정의로 설정하세요.
   - 기존 계정으로 로그인하는 테스트에는 `INTEGRATION_TEST_EMAIL`도 필요합니다.

2. **테스트 데이터 주의**
   - 회원가입 테스트는 설정한 테스트 서버에 데이터를 만들 수 있으므로 일회용 계정과 폐기 가능한 데이터베이스를 사용하세요.

3. **실행 시간**
   - 네트워크 호출로 인해 느릴 수 있음
   - `pumpAndSettle`에 충분한 시간 부여

## 테스트 파일 구조

```
integration_test/
├── app_test.dart          # 메인 통합 테스트
├── auth_test.dart         # 인증 관련 테스트 (추가 가능)
├── post_test.dart         # 게시글 관련 테스트 (추가 가능)
└── README.md             # 이 파일
```

## VS Code에서 실행

`.vscode/launch.json`에 통합 테스트 실행 설정 추가 가능:
```json
{
  "name": "Integration Tests",
  "request": "launch",
  "type": "dart",
  "program": "integration_test/app_test.dart"
}
```
