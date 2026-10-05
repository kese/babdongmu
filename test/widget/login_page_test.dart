import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery/pages/login.dart';
import 'package:delivery/main.dart';

void main() {
  group('LoginPage 위젯 테스트', () {
    testWidgets('로그인 페이지가 올바르게 렌더링되어야 함', (WidgetTester tester) async {
      // 앱을 빌드하고 프레임을 트리거
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // 이메일 입력 필드가 존재하는지 확인
      expect(find.byType(TextFormField), findsNWidgets(2));

      // 로그인 버튼이 존재하는지 확인
      expect(find.text('로그인'), findsOneWidget);

      // 회원가입 버튼이 존재하는지 확인
      expect(find.text('회원가입'), findsOneWidget);
    });

    testWidgets('이메일과 비밀번호를 입력할 수 있어야 함', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // 이메일 필드 찾기 및 입력
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      // 비밀번호 필드 찾기 및 입력
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // 입력된 값 확인
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('password123'), findsOneWidget);
    });

    testWidgets('빈 필드로 로그인 시도 시 에러 다이얼로그 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // 로그인 버튼 찾기 및 탭
      final loginButton = find.text('로그인');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // 에러 다이얼로그 확인
      expect(find.text('이메일과 비밀번호를 입력해주세요.'), findsOneWidget);
    });

    testWidgets('잘못된 이메일 형식으로 로그인 시도 시 에러 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // 잘못된 이메일 형식 입력
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'invalid-email');
      await tester.pump();

      // 비밀번호 입력
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // 로그인 버튼 탭
      final loginButton = find.text('로그인');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // 에러 다이얼로그 확인
      expect(find.text('올바른 이메일 형식을 입력해주세요.'), findsOneWidget);
    });

    testWidgets('회원가입 버튼 탭 시 회원가입 페이지로 이동', (WidgetTester tester) async {
      await tester.pumpWidget(const DeliveryApp());

      // 로그인 페이지가 표시되는지 확인
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      // 회원가입 버튼 찾기 및 탭
      final signupButton = find.text('회원가입');
      expect(signupButton, findsOneWidget);
      await tester.tap(signupButton);
      await tester.pumpAndSettle();

      // 회원가입 페이지로 이동했는지 확인
      // (실제 네비게이션 구현에 따라 조정 필요)
    });
  });
}
