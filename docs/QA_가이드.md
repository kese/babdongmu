# QA 작업 가이드

## 1. 테스트 종류

### 1.1 유닛 테스트 (Unit Tests)
- **위치**: `test/unit/`
- **목적**: 개별 함수, 클래스, 메서드의 로직 검증
- **대상**: 
  - API 서비스 (`lib/services/*`)
  - 모델 클래스 (`lib/models/*`)
  - 유틸리티 함수 (`lib/utils/*`)

### 1.2 위젯 테스트 (Widget Tests)
- **위치**: `test/widget/`
- **목적**: UI 컴포넌트의 렌더링 및 상호작용 검증
- **대상**: 
  - 페이지 (`lib/pages/*`)
  - 위젯 (`lib/widgets/*`)

### 1.3 통합 테스트 (Integration Tests)
- **위치**: `integration_test/`
- **목적**: 전체 앱 플로우 및 기능 시나리오 검증
- **대상**: 
  - 사용자 시나리오 (로그인 → 게시글 작성 → 채팅 등)

## 2. 테스트 실행 방법

### 2.1 모든 테스트 실행
```bash
flutter test
```

### 2.2 특정 테스트 파일 실행
```bash
flutter test test/widget/login_test.dart
```

### 2.3 테스트 커버리지 측정
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### 2.4 통합 테스트 실행
```bash
flutter test integration_test
```

## 3. 테스트 작성 체크리스트

### 3.1 인증 기능
- [ ] 로그인 성공 시나리오
- [ ] 로그인 실패 시나리오 (잘못된 이메일/비밀번호)
- [ ] 회원가입 폼 검증
- [ ] 토큰 저장 및 로드

### 3.2 게시글 기능
- [ ] 배달 게시글 작성
- [ ] 친구 구하기 게시글 작성
- [ ] 게시글 목록 조회
- [ ] 게시글 상세 조회
- [ ] 게시글 참여

### 3.3 채팅 기능
- [ ] 채팅방 목록 조회
- [ ] 채팅방 생성
- [ ] 메시지 전송 및 수신
- [ ] 실시간 업데이트

### 3.4 합동 주문 기능
- [ ] 주문 요청 생성
- [ ] 주문 상태 업데이트
- [ ] 정산 요청

### 3.5 지도 및 위치 기능
- [ ] 현재 위치 표시
- [ ] 장소 검색
- [ ] 장소 선택

### 3.6 알림 기능
- [ ] 알림 수신
- [ ] 알림 목록 표시
- [ ] 읽음 처리

## 4. 테스트 작성 예시

### 4.1 유닛 테스트 예시
```dart
// test/unit/services/auth_api_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery/services/auth_api.dart';

void main() {
  group('AuthApi', () {
    test('로그인 성공 시 토큰을 반환해야 함', () async {
      // 테스트 코드
    });
    
    test('잘못된 이메일로 로그인 시 에러를 반환해야 함', () async {
      // 테스트 코드
    });
  });
}
```

### 4.2 위젯 테스트 예시
```dart
// test/widget/login_page_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery/pages/login.dart';

void main() {
  testWidgets('로그인 페이지가 올바르게 렌더링되어야 함', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
```

## 5. 테스트 우선순위

### 높은 우선순위
1. 로그인/회원가입 (인증)
2. 게시글 작성 및 조회
3. 채팅 메시지 전송

### 중간 우선순위
4. 합동 주문 플로우
5. 알림 수신
6. 지도 및 위치 기능

### 낮은 우선순위
7. 프로필 수정
8. UI 애니메이션 및 전환

## 6. 테스트 환경 설정

### 6.1 Mock 데이터 사용
- API 호출을 Mock으로 대체하여 실제 서버 없이 테스트
- `mockito` 또는 `mocktail` 패키지 활용

### 6.2 테스트 데이터
- `lib/dummy_data/` 폴더의 더미 데이터 활용
- 공유 테스트 계정은 제공하지 않습니다. 격리된 환경에서 개인 테스트 계정을 사용하세요.

## 7. 버그 리포팅 템플릿

```markdown
### 버그 제목
[카테고리] 버그 설명

### 재현 단계
1. 
2. 
3. 

### 예상 동작
- 

### 실제 동작
- 

### 환경
- Flutter 버전: 
- 디바이스: 
- OS 버전: 

### 스크린샷/로그
- 
```

## 8. QA 작업 프로세스

1. **테스트 계획 수립**: 테스트할 기능 목록 작성
2. **테스트 케이스 작성**: 각 기능별 테스트 시나리오 작성
3. **테스트 실행**: 자동화 테스트 + 수동 테스트
4. **버그 리포팅**: 발견된 버그를 체계적으로 문서화
5. **회귀 테스트**: 버그 수정 후 재테스트
6. **커버리지 확인**: 테스트 커버리지 목표 달성 확인

## 9. 테스트 커버리지 목표

- **최소 목표**: 60% 이상
- **권장 목표**: 80% 이상
- **핵심 기능**: 90% 이상 (인증, 결제 관련)

## 10. 유용한 명령어

```bash
# 테스트 실행 및 커버리지 생성
flutter test --coverage

# 커버리지 리포트 확인 (HTML)
# coverage/html/index.html 파일 열기

# 특정 패턴의 테스트만 실행
flutter test --name "로그인"

# 테스트 실행 시간 표시
flutter test --reporter expanded
```
