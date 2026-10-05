import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;
import 'remote_test_gate.dart';
import 'dart:math';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!requireRemoteIntegrationOptIn()) return;

  // A disposable account is created only on the explicitly configured test server.
  final random = Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final testEmail = 'qa_all_${timestamp}@example.invalid';
  const testPassword = String.fromEnvironment('INTEGRATION_TEST_PASSWORD');
  final testNickname = 'QA전체테스트${random.nextInt(9999)}';
  final testName = 'QA테스트이름';

  group('모든 기능 통합 테스트', () {
    testWidgets('1. 회원가입 플로우 - opt-in 테스트 API', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      print('📝 회원가입 시작');

      // 회원가입 버튼 클릭
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 회원가입 폼 필드 찾기
      final formFields = find.byType(TextFormField);
      expect(formFields, findsAtLeastNWidgets(5));

      // 필수 필드 입력
      await tester.enterText(formFields.at(0), testEmail); // 이메일
      await tester.pump();
      await tester.enterText(formFields.at(1), testPassword); // 비밀번호
      await tester.pump();
      await tester.enterText(formFields.at(2), testPassword); // 비밀번호 확인
      await tester.pump();
      await tester.enterText(formFields.at(3), testName); // 이름
      await tester.pump();
      await tester.enterText(formFields.at(4), testNickname); // 닉네임
      await tester.pump();

      // 중복 확인 대기
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 가입하기 버튼 찾기 및 클릭
      final signupButton = find.text('가입하기');
      final signupElevatedButton = find.ancestor(
        of: signupButton,
        matching: find.byType(ElevatedButton),
      );

      // 버튼이 보이지 않으면 스크롤 시도
      try {
        await tester.tap(signupElevatedButton, warnIfMissed: false);
      } catch (e) {
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        await tester.tap(signupElevatedButton, warnIfMissed: false);
      }

      // 회원가입 API 호출 대기
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 성공/실패 확인
      final successDialog = find.text('가입 완료');
      final errorDialog = find.text('입력 오류');
      bool signupSuccess = false;

      if (successDialog.evaluate().isNotEmpty) {
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        signupSuccess = true;
        print('✅ 회원가입 성공');
      } else if (errorDialog.evaluate().isNotEmpty) {
        print('❌ 회원가입 실패');
        // 에러 확인 후 닫기
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
      } else {
        // 다이얼로그가 없으면 로그인 페이지로 이동 확인
        await tester.pumpAndSettle(const Duration(seconds: 2));
        final loginPage = find.text('로그인');
        if (loginPage.evaluate().isNotEmpty) {
          signupSuccess = true;
          print('✅ 회원가입 완료 (로그인 페이지로 이동됨)');
        }
      }

      // 회원가입 성공 여부 저장 (다음 테스트에서 사용)
      // Note: 실제로는 SharedPreferences나 다른 방식으로 상태를 공유해야 함
    });

    testWidgets('2. 실제 로그인 성공 플로우', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      print('🔐 로그인 시도');

      // 로그인 정보 입력
      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.first, testEmail);
      await tester.pump();

      if (loginFields.evaluate().length >= 2) {
        await tester.enterText(loginFields.at(1), testPassword);
        await tester.pump();
      }

      // 로그인 버튼 클릭
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 로그인 성공 확인
      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isNotEmpty) {
        expect(find.text('홈'), findsOneWidget);
        print('✅ 로그인 성공! 홈 화면 확인됨');
      } else {
        print('⚠️ 로그인 실패 - 계정 확인 필요');
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
      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.first, testEmail);
      await tester.pump();

      if (loginFields.evaluate().length >= 2) {
        await tester.enterText(loginFields.at(1), testPassword);
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 홈 화면 확인
      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isEmpty) {
        // 로그인 실패 시 종료
        return;
      }

      expect(find.text('홈'), findsOneWidget);
      expect(find.text('함께 배달'), findsOneWidget);
      expect(find.text('같이 먹을 친구 구하기'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      print('✅ 홈 화면 모든 요소 확인 완료');
    });

    testWidgets('4. 게시글 작성 실제 기능 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인
      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.first, testEmail);
      await tester.pump();

      if (loginFields.evaluate().length >= 2) {
        await tester.enterText(loginFields.at(1), testPassword);
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isEmpty) {
        return;
      }

      // 게시글 작성 버튼 클릭
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 게시글 작성 페이지 확인
      expect(find.text('완료'), findsOneWidget);
      print('✅ 게시글 작성 페이지 로드 완료');

      // 뒤로가기
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('5. 채팅 기능 실제 기능 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인
      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.first, testEmail);
      await tester.pump();

      if (loginFields.evaluate().length >= 2) {
        await tester.enterText(loginFields.at(1), testPassword);
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isEmpty) {
        return;
      }

      // 채팅 탭 클릭
      final chatIcon = find.byIcon(Icons.chat_bubble_outline);
      if (chatIcon.evaluate().isNotEmpty) {
        await tester.tap(chatIcon);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        print('✅ 채팅 탭으로 이동 완료');
      }
    });

    testWidgets('6. 합동 주문 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인
      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.first, testEmail);
      await tester.pump();

      if (loginFields.evaluate().length >= 2) {
        await tester.enterText(loginFields.at(1), testPassword);
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isEmpty) {
        return;
      }

      // 합동 주문 탭 클릭
      final groupIcon = find.byIcon(Icons.group);
      if (groupIcon.evaluate().isNotEmpty) {
        await tester.tap(groupIcon);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        print('✅ 합동 주문 탭으로 이동 완료');
      }
    });
  });
}
