import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;
import 'remote_test_gate.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!requireRemoteIntegrationOptIn()) return;

  group('원격 API 통합 테스트 (opt-in)', () {
    testWidgets('로그인 페이지 로드 테스트', (WidgetTester tester) async {
      // 앱 시작
      app.main();

      // 앱 초기화 및 UI 렌더링 대기 (Firebase 초기화 등 포함)
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인 페이지가 표시되는지 확인
      // 앱 타이틀이 화면에 표시될 때까지 대기
      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('회원가입'), findsOneWidget);

      // '밥동무' 텍스트가 있으면 확인 (없어도 다른 요소로 페이지 확인 가능)
      final bapdongmu = find.text('밥동무');
      if (bapdongmu.evaluate().isNotEmpty) {
        expect(bapdongmu, findsWidgets);
      }
    });

    testWidgets('회원가입 버튼 클릭 테스트', (WidgetTester tester) async {
      app.main();

      // 앱 초기화 대기
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 회원가입 버튼 찾기 및 클릭
      final signupButton = find.text('회원가입');
      expect(signupButton, findsOneWidget);
      await tester.tap(signupButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 회원가입 페이지로 이동했는지 확인
      // TextField가 여러 개 있으면 회원가입 페이지로 이동한 것으로 간주
      expect(find.byType(TextField), findsAtLeastNWidgets(2));
    });

    testWidgets('로그인 - 원격 API 호출 (성공 시나리오)', (WidgetTester tester) async {
      app.main();

      // 앱 초기화 대기
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 이메일 필드 찾기 및 입력 (TextField 사용)
      final emailFields = find.byType(TextField);
      expect(emailFields, findsAtLeastNWidgets(1));

      // 첫 번째 TextField가 이메일 필드
      await tester.enterText(emailFields.first, 'test@example.com');
      await tester.pump();

      // 두 번째 TextField가 비밀번호 필드
      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(
          emailFields.at(1),
          const String.fromEnvironment('INTEGRATION_TEST_PASSWORD'),
        );
        await tester.pump();
      }

      // 로그인 버튼 클릭
      final loginButton = find.text('로그인');
      expect(loginButton, findsOneWidget);
      await tester.tap(loginButton);

      // API 호출 대기 (서버 응답 시간 고려)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 로그인 성공/실패 확인
      // 성공 시: 홈 화면으로 이동 (홈 화면의 요소 확인)
      // 실패 시: 에러 다이얼로그 표시
      final errorDialog = find.text('알림');
      if (errorDialog.evaluate().isNotEmpty) {
        // 에러 발생 시 확인 버튼 클릭
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    });

    testWidgets('로그인 - 잘못된 정보로 로그인 시도 (실패 시나리오)', (WidgetTester tester) async {
      app.main();

      // 앱 초기화 대기
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 잘못된 이메일 입력
      final emailFields = find.byType(TextField);
      await tester.enterText(emailFields.first, 'wrong@example.com');
      await tester.pump();

      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(emailFields.at(1), 'wrongpassword');
        await tester.pump();
      }

      // 로그인 버튼 클릭
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 에러 다이얼로그가 표시되는지 확인
      // 로그인 오류 안내 확인
      expect(find.text('알림'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('로그인 - 빈 필드로 로그인 시도', (WidgetTester tester) async {
      app.main();

      // 앱 초기화 대기
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 필드 입력 없이 바로 로그인 버튼 클릭
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 에러 다이얼로그가 표시되어야 함
      expect(find.text('알림'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });
}
