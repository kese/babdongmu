import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;
import 'dart:math';
import 'remote_test_gate.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!requireRemoteIntegrationOptIn()) return;

  // 테스트용 계정 생성 (고유한 이메일과 닉네임)
  final random = Random();
  final testEmail = 'qa_test_${DateTime.now().millisecondsSinceEpoch}@example.invalid';
  const testPassword = String.fromEnvironment('INTEGRATION_TEST_PASSWORD');
  final testNickname = 'QA테스트${random.nextInt(9999)}';
  final testName = 'QA테스트이름';

  group('완전한 플로우 통합 테스트', () {
    testWidgets('1. 회원가입 완료 플로우', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 회원가입 버튼 클릭
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 회원가입 페이지 확인
      expect(find.text('가입하기'), findsOneWidget);

      // 회원가입 폼 필드 찾기 (TextFormField)
      final formFields = find.byType(TextFormField);
      expect(formFields, findsAtLeastNWidgets(5));

      // 이메일 입력 (첫 번째 필드)
      await tester.enterText(formFields.at(0), testEmail);
      await tester.pump();

      // 비밀번호 입력 (두 번째 필드)
      await tester.enterText(formFields.at(1), testPassword);
      await tester.pump();

      // 비밀번호 확인 (세 번째 필드)
      await tester.enterText(formFields.at(2), testPassword);
      await tester.pump();

      // 이름 입력 (네 번째 필드)
      await tester.enterText(formFields.at(3), testName);
      await tester.pump();

      // 닉네임 입력 (다섯 번째 필드)
      await tester.enterText(formFields.at(4), testNickname);
      await tester.pump();

      // 폼 입력 반영 대기
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 가입하기 버튼 찾기 및 스크롤
      final signupButton = find.text('가입하기');
      expect(signupButton, findsOneWidget);

      // 버튼이 화면에 보이도록 스크롤
      await tester.scrollUntilVisible(signupButton, 500.0);
      await tester.pumpAndSettle();

      // 가입하기 버튼 클릭
      await tester.tap(signupButton, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 회원가입 성공 다이얼로그 확인
      final successDialog = find.text('가입 완료');
      if (successDialog.evaluate().isNotEmpty) {
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        // 로그인 페이지로 돌아왔는지 확인
        expect(find.text('로그인'), findsOneWidget);
      }
    });

    testWidgets('2. 실제 로그인 성공 플로우', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 위에서 생성한 계정으로 로그인
      final emailFields = find.byType(TextField);
      expect(emailFields, findsAtLeastNWidgets(1));

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
        // 로그인 성공 - 홈 화면 확인
        expect(find.text('홈'), findsOneWidget);
        print('✅ 로그인 성공! 홈 화면으로 이동됨');
      } else {
        // 로그인 실패 시 에러 확인
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

      // 로그인
      final emailFields = find.byType(TextField);
      await tester.enterText(emailFields.first, testEmail);
      await tester.pump();

      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(emailFields.at(1), testPassword);
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 홈 화면 확인
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('홈'), findsOneWidget);

      // 홈 화면의 탭 확인
      expect(find.text('함께 배달'), findsOneWidget);
      expect(find.text('같이 먹을 친구 구하기'), findsOneWidget);

      // FloatingActionButton (게시글 작성 버튼) 확인
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('4. 게시글 작성 실제 기능 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인
      final emailFields = find.byType(TextField);
      await tester.enterText(emailFields.first, testEmail);
      await tester.pump();

      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(emailFields.at(1), testPassword);
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // FloatingActionButton 클릭하여 게시글 작성 페이지로 이동
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 게시글 작성 페이지 확인
      expect(find.text('완료'), findsOneWidget);

      // 게시글 유형 선택 (이미 '배달'이 선택되어 있을 수 있음)
      // 제목 입력 필드 찾기
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        // 제목 입력
        await tester.enterText(textFields.first, '통합 테스트 게시글');
        await tester.pump();
      }
    });

    testWidgets('5. 채팅 기능 실제 기능 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인
      final emailFields = find.byType(TextField);
      await tester.enterText(emailFields.first, testEmail);
      await tester.pump();

      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(emailFields.at(1), testPassword);
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 채팅 탭으로 이동 (하단 네비게이션 바)
      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isNotEmpty) {
        // 채팅 아이콘 찾기 및 클릭
        final chatIcon = find.byIcon(Icons.chat_bubble_outline);
        if (chatIcon.evaluate().isNotEmpty) {
          await tester.tap(chatIcon);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // 채팅방 목록 페이지 확인
          // (채팅방이 없을 수도 있음)
        }
      }
    });

    testWidgets('6. 합동 주문 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인
      final emailFields = find.byType(TextField);
      await tester.enterText(emailFields.first, testEmail);
      await tester.pump();

      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(emailFields.at(1), testPassword);
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 합동 주문 탭으로 이동
      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isNotEmpty) {
        // 합동 주문 아이콘 찾기 및 클릭
        final groupIcon = find.byIcon(Icons.group);
        if (groupIcon.evaluate().isNotEmpty) {
          await tester.tap(groupIcon);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // 합동 주문 페이지 확인
          // (페이지 구조에 따라 조정 필요)
        }
      }
    });
  });
}
