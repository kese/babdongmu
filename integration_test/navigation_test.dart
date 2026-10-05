import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('네비게이션 테스트', () {
    testWidgets('회원가입 페이지에서 로그인 페이지로 돌아가기', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 회원가입 버튼 클릭
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 회원가입 페이지 확인
      expect(find.byType(TextField), findsAtLeastNWidgets(2));

      // 뒤로가기 버튼 찾기 및 클릭
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 로그인 페이지로 돌아왔는지 확인
        expect(find.text('로그인'), findsOneWidget);
      }
    });
  });
}
