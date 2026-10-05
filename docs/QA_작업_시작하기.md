# QA 작업 시작하기

## 빠른 시작

QA 작업을 시작하기 전에 다음 문서들을 확인하세요:

1. **[QA_가이드.md](./QA_가이드.md)** - 테스트 작성 방법 및 전략
2. **[QA_체크리스트.md](./QA_체크리스트.md)** - 테스트해야 할 기능 목록
3. **[../test/README.md](../test/README.md)** - 테스트 실행 방법

## 1단계: 테스트 환경 확인

### 테스트 실행
```bash
# 모든 테스트 실행
flutter test

# 특정 테스트 파일 실행
flutter test test/unit/services/auth_api_test.dart

# 테스트 커버리지 확인
flutter test --coverage
```

### 테스트 구조 확인
```
test/
├── unit/              # 유닛 테스트
│   └── services/
│       └── auth_api_test.dart
├── widget/            # 위젯 테스트
│   └── login_page_test.dart
└── widget_test.dart   # 기본 테스트
```

## 2단계: 수동 테스트 시작

### 기본 기능 테스트
1. 앱 실행
2. 격리된 테스트 환경의 개인 계정으로 로그인
3. 각 메인 화면 이동 확인
4. 기본 기능 동작 확인

### 체크리스트 사용
`docs/QA_체크리스트.md` 파일의 체크리스트를 따라 하나씩 확인하세요.

## 3단계: 자동화 테스트 작성

### 새로운 테스트 작성 방법

#### 1. 유닛 테스트 작성
예시: `test/unit/services/post_api_test.dart` 생성
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery/services/post_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostApi 테스트', () {
    test('게시글 목록 조회가 성공해야 함', () async {
      // 테스트 코드 작성
    });
  });
}
```

#### 2. 위젯 테스트 작성
예시: `test/widget/create_post_test.dart` 생성
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery/pages/create_post.dart';

void main() {
  testWidgets('게시글 작성 페이지 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CreatePostPage()),
    );
    
    // UI 확인
    expect(find.text('게시글 작성'), findsOneWidget);
  });
}
```

## 4단계: 버그 발견 시

1. 버그 발견 시 `docs/버그리포트/` 폴더에 리포트 작성
2. 파일명: `버그_YYYYMMDD_HHMM.md`
3. 템플릿 사용: `docs/버그리포트/버그리포트_템플릿.md`

예시:
```markdown
# 버그 리포트

## 버그 제목
[인증] 로그인 후 홈 화면으로 이동하지 않음

## 재현 단계
1. 앱 실행
2. 로그인 버튼 클릭
...

## 예상 동작
로그인 성공 시 홈 화면으로 이동해야 함

## 실제 동작
로그인 성공 후에도 로그인 화면에 머무름
...
```

## 5단계: 테스트 커버리지 확인

```bash
# 커버리지 생성
flutter test --coverage

# 커버리지 리포트 확인 (HTML)
# coverage/html/index.html 파일을 브라우저로 열기
```

### 커버리지 목표
- **최소**: 60%
- **권장**: 80%
- **핵심 기능**: 90% (인증, 결제 등)

## 우선순위별 테스트 계획

### 1주차: 핵심 기능
- [ ] 인증 (로그인/회원가입)
- [ ] 게시글 작성/조회
- [ ] 기본 네비게이션

### 2주차: 주요 기능
- [ ] 채팅 기능
- [ ] 합동 주문
- [ ] 알림 기능

### 3주차: 추가 기능
- [ ] 지도/위치 기능
- [ ] 마이페이지
- [ ] UI/UX 검증

## 유용한 명령어

```bash
# 특정 테스트만 실행
flutter test --name "로그인"

# 테스트 재실행 (watch mode)
flutter test --watch

# 테스트 실행 시간 표시
flutter test --reporter expanded

# 커버리지 리포트 생성
flutter test --coverage
```

## 문제 해결

### 테스트 실행 오류
- `TestWidgetsFlutterBinding.ensureInitialized()` 추가 확인
- Mock 설정 확인 (SharedPreferences 등)

### 플러그인 관련 오류
- 테스트용 Mock 플러그인 사용 고려
- 또는 해당 기능은 통합 테스트로 이동

## 다음 단계

1. 체크리스트를 따라 수동 테스트 수행
2. 발견한 버그를 문서화
3. 자동화 테스트 작성
4. 테스트 커버리지 향상
5. 회귀 테스트 수행

## 도움말

- [Flutter 테스트 공식 문서](https://docs.flutter.dev/testing)
- 프로젝트 내 `docs/QA_가이드.md` 참고
- 팀원과 버그 리포트 공유
