import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;
import 'remote_test_gate.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!requireRemoteIntegrationOptIn(requiresExistingAccount: true)) return;

  group('로그인 성공 플로우 통합 테스트', () {
    testWidgets('로그인 후 홈 화면 이동 및 UI 확인', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인 페이지 확인
      expect(find.text('로그인'), findsOneWidget);

      // Explicitly configured integration account
      final emailFields = find.byType(TextField);
      expect(emailFields, findsAtLeastNWidgets(1));

      // 이메일 입력
      await tester.enterText(
        emailFields.first,
        const String.fromEnvironment('INTEGRATION_TEST_EMAIL'),
      );
      await tester.pump();

      // 비밀번호 입력
      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(
          emailFields.at(1),
          const String.fromEnvironment('INTEGRATION_TEST_PASSWORD'),
        );
        await tester.pump();
      }

      // 로그인 버튼 클릭
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 홈 화면으로 이동했는지 확인
      // 하단 네비게이션 바 확인
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // 홈 탭이 선택되어 있는지 확인
      expect(find.text('홈'), findsOneWidget);
    });

    testWidgets('홈 화면 탭 구조 확인', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인
      final emailFields = find.byType(TextField);
      await tester.enterText(
        emailFields.first,
        const String.fromEnvironment('INTEGRATION_TEST_EMAIL'),
      );
      await tester.pump();

      if (emailFields.evaluate().length >= 2) {
        await tester.enterText(
          emailFields.at(1),
          const String.fromEnvironment('INTEGRATION_TEST_PASSWORD'),
        );
        await tester.pump();
      }

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 홈 화면의 탭 확인 ('함께 배달', '같이 먹을 친구 구하기')
      expect(find.text('함께 배달'), findsOneWidget);
      expect(find.text('같이 먹을 친구 구하기'), findsOneWidget);
    });
  });
}
