import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('게시글 기능 통합 테스트', () {
    testWidgets('게시글 작성 페이지 로드 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인 후 게시글 작성 페이지로 이동하는 시나리오
      // 일단 기본 UI 확인만 진행
    });

    testWidgets('배달 게시글 작성 폼 확인', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 게시글 작성 페이지에서 배달 탭 확인
      // 폼 필드 확인
    });

    testWidgets('친구 구하기 게시글 작성 폼 확인', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 게시글 작성 페이지에서 친구 구하기 탭 확인
      // 폼 필드 확인
    });
  });
}
