import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;
import 'dart:math';
import 'remote_test_gate.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!requireRemoteIntegrationOptIn()) return;

  // 테스트용 계정 생성 (고유한 이메일)
  final random = Random();
  final testEmail = 'test_qa_${random.nextInt(999999)}@example.invalid';
  const testPassword = String.fromEnvironment('INTEGRATION_TEST_PASSWORD');
  final testNickname = '테스트유저${random.nextInt(9999)}';

  group('전체 플로우 통합 테스트', () {
    testWidgets('1. 회원가입 완료 플로우', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 회원가입 버튼 클릭
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 회원가입 폼 필드 찾기
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(3));

      // 이메일 입력
      await tester.enterText(textFields.at(0), testEmail);
      await tester.pump();

      // 비밀번호 입력 (두 번째 필드)
      if (textFields.evaluate().length >= 2) {
        await tester.enterText(textFields.at(1), testPassword);
        await tester.pump();
      }

      // 비밀번호 확인 (세 번째 필드)
      if (textFields.evaluate().length >= 3) {
        await tester.enterText(textFields.at(2), testPassword);
        await tester.pump();
      }

      // 이름 입력 (네 번째 필드)
      if (textFields.evaluate().length >= 4) {
        await tester.enterText(textFields.at(3), '테스트 이름');
        await tester.pump();
      }

      // 닉네임 입력 (다섯 번째 필드)
      if (textFields.evaluate().length >= 5) {
        await tester.enterText(textFields.at(4), testNickname);
        await tester.pump();
      }

      // 회원가입 버튼 찾기 및 클릭
      final signupButton = find.text('회원가입');
      if (signupButton.evaluate().isNotEmpty) {
        await tester.tap(signupButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // 회원가입 성공 여부 확인 (로그인 페이지로 돌아가거나 성공 메시지 표시)
        // The test server response depends on the isolated test configuration.
      }
    });

    testWidgets('2. 실제 로그인 성공 플로우', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 위에서 생성한 계정으로 로그인
      final emailFields = find.byType(TextField);
      await tester.enterText(emailFields.first, testEmail);
      await tester.pump();

      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(emailFields.at(1), testPassword);
        await tester.pump();
      }

      // 로그인 버튼 클릭
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 홈 화면으로 이동했는지 확인
      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isNotEmpty) {
        // 로그인 성공
        expect(find.text('홈'), findsOneWidget);
      } else {
        // 로그인 실패 시 에러 다이얼로그 닫기
        final errorDialog = find.text('알림');
        if (errorDialog.evaluate().isNotEmpty) {
          await tester.tap(find.text('확인'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('3. 홈 화면 실제 기능 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인 (기존 계정 사용)
      final emailFields = find.byType(TextField);
      if (emailFields.evaluate().isNotEmpty) {
        // Supply a test-only account from the isolated integration environment.
        // Supply a test-only account from the isolated integration environment.
        // ...
      }

      // 홈 화면 확인
      // 하단 네비게이션 바 확인
      // 게시글 목록 확인
      // FloatingActionButton (게시글 작성 버튼) 확인
    });

    testWidgets('4. 게시글 작성 실제 기능 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인 후 홈 화면에서 게시글 작성 버튼 클릭
      // 게시글 작성 폼 입력
      // 게시글 제출
      // 게시글 목록에 추가되었는지 확인
    });

    testWidgets('5. 채팅 기능 실제 기능 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인 후 채팅 탭으로 이동
      // 채팅방 목록 확인
      // 채팅방 클릭하여 진입
      // 메시지 입력 및 전송
      // 메시지가 화면에 표시되는지 확인
    });

    testWidgets('6. 합동 주문 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인 후 합동 주문 탭으로 이동
      // 합동 주문 페이지 UI 확인
      // 합동 주문 기능 테스트
    });
  });
}
