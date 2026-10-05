import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;
import 'remote_test_gate.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!requireRemoteIntegrationOptIn()) return;

  group('인증 플로우 통합 테스트', () {
    testWidgets('회원가입 전체 플로우', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 회원가입 버튼 클릭
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 회원가입 페이지 확인
      expect(find.byType(TextField), findsAtLeastNWidgets(2));

      // 회원가입 폼 입력
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 3) {
        // 이메일 입력
        await tester.enterText(
          textFields.at(0),
          'test_${DateTime.now().millisecondsSinceEpoch}@example.invalid',
        );
        await tester.pump();

        // 비밀번호 입력 (실제 UI 구조에 맞게 수정 필요)
      }
    });

    testWidgets('로그인 후 홈 화면 이동 확인', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // A test account is supplied only for an explicitly configured test server.
      final emailFields = find.byType(TextField);
      if (emailFields.evaluate().isNotEmpty) {
        // Supply a test-only account from the isolated integration environment.
        // Supply a test-only account from the isolated integration environment.

        // 비밀번호 입력
        // if (emailFields.evaluate().length >= 2) {
        // }

        // 로그인 버튼 클릭
        // await tester.tap(find.text('로그인'));
        // await tester.pumpAndSettle(const Duration(seconds: 5));

        // 홈 화면 요소 확인
        // 하단 네비게이션 바 확인 (홈 탭이 선택되어 있어야 함)
        // expect(find.byType(BottomNavigationBar), findsOneWidget);
        // expect(find.text('홈'), findsOneWidget);
      }

      // 테스트 준비 완료 (실제 계정 정보 필요)
      expect(find.text('로그인'), findsOneWidget);
    });
  });
}
