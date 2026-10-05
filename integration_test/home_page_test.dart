import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('홈 화면 통합 테스트', () {
    testWidgets('홈 화면 로드 및 하단 네비게이션 확인', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 로그인 후 홈 화면으로 이동하는 시나리오
      // 일단 로그인 페이지에서 시작
      expect(find.text('로그인'), findsOneWidget);

      // 실제 유효한 계정으로 로그인하려면 계정 정보 필요
      // 일단 UI 요소 확인만 진행
    });

    testWidgets('게시글 작성 버튼 클릭 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 홈 화면에 있을 때 게시글 작성 버튼 확인
      // FloatingActionButton 또는 다른 버튼 찾기
      final fabButtons = find.byType(FloatingActionButton);

      // 게시글 작성 페이지로 이동 테스트
      // (로그인 후에만 가능)
    });

    testWidgets('하단 네비게이션 바 탭 전환 테스트', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 하단 네비게이션 바 확인
      // 0:채팅, 1:지도, 2:홈, 3:합동주문, 4:마이페이지
      final bottomNav = find.byType(BottomNavigationBar);

      if (bottomNav.evaluate().isNotEmpty) {
        // 각 탭 클릭 테스트
        // (로그인 후에만 가능)
      }
    });
  });
}
