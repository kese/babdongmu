import 'package:flutter_test/flutter_test.dart';
import 'package:delivery/services/auth_api.dart';
import 'package:delivery/dummy_data/dummy.dart';
import 'package:delivery/services/api.dart';

void main() {
  // Flutter 바인딩 초기화 (SharedPreferences 등 사용 시 필요)
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthApi 테스트', () {
    // 각 테스트 전에 실행되는 설정
    setUp(() {
      // 테스트 간 격리를 위해 더미 데이터 초기화
      DummyAuthStore.tempUsers.clear();
    });

    group('회원가입', () {
      test('회원가입이 성공적으로 완료되어야 함', () async {
        final result = await AuthApi.signUp(
          email: 'test@example.com',
          password: 'password123!',
          username: '테스트 사용자',
          nickname: '테스트닉',
        );

        expect(result['success'], true);
        expect(result['message'], '회원가입 성공');
        expect(DummyAuthStore.tempUsers.length, 1);
      });

      test('중복된 이메일로 회원가입 시 실패해야 함', () async {
        // 첫 번째 회원가입
        await AuthApi.signUp(
          email: 'duplicate@example.com',
          password: 'password123!',
          username: '사용자1',
          nickname: '닉1',
        );

        // 동일한 이메일로 두 번째 회원가입 시도
        final result = await AuthApi.signUp(
          email: 'duplicate@example.com',
          password: 'password123!',
          username: '사용자2',
          nickname: '닉2',
        );

        expect(result['success'], false);
        expect(result['message'], '이미 가입된 이메일입니다');
      });

      test('선택적 필드가 있는 회원가입이 성공해야 함', () async {
        final result = await AuthApi.signUp(
          email: 'full@example.com',
          password: 'password123!',
          username: '전체정보',
          nickname: '전체닉',
          address: '서울시 강남구',
          phoneNumber: '000-0000-0000',
          account: '123-456-789',
        );

        expect(result['success'], true);
        final user = DummyAuthStore.tempUsers.firstWhere(
          (u) => u['email'] == 'full@example.com',
        );
        expect(user['address'], '서울시 강남구');
        expect(user['phoneNumber'], '000-0000-0000');
      });
    });

    group('로그인', () {
      test('잘못된 이메일로 로그인 시 실패해야 함', () async {
        final result = await AuthApi.login(
          email: 'wrong@example.com',
          password: 'password123!',
        );

        expect(result['success'], false);
        expect(result['message'], '이메일 또는 비밀번호가 일치하지 않습니다');
      });

      test('잘못된 비밀번호로 로그인 시 실패해야 함', () async {
        // 먼저 회원가입
        await AuthApi.signUp(
          email: 'testlogin@example.com',
          password: 'correct123!',
          username: '로그인테스트',
          nickname: '로그인닉',
        );

        // 잘못된 비밀번호로 로그인 시도
        final result = await AuthApi.login(
          email: 'testlogin@example.com',
          password: 'wrongpassword!',
        );

        expect(result['success'], false);
      });

      test('정확한 정보로 로그인 시 성공해야 함', () async {
        // 회원가입
        await AuthApi.signUp(
          email: 'testlogin2@example.com',
          password: 'password123!',
          username: '로그인테스트2',
          nickname: '로그인닉2',
        );

        // 로그인
        final result = await AuthApi.login(
          email: 'testlogin2@example.com',
          password: 'password123!',
        );

        expect(result['success'], true);
        expect(result['data']['token'], startsWith('mock-'));
      });
    });

  });
}
