import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/notification_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // textfield의 텍스트 제어 및 사용자가 입력한 값을 가져오기 위한 컨트롤러
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  // 키보드 포커스 관리
  final _passwordFocusNode = FocusNode();
  // API 호출 동안 로딩 인디케이터 화면 표시 여부를 결정하는 상태 변수
  bool _isLoading = false;

  @override
  // 위젯이 화면에서 완전히 사라질때 호출
  // 메모리 누수 방지
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // 정규 표현식을 사용하여 이메일 형식이 올바른지 확인하는 헬퍼 함수 (유효성 검사)
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // 사용자가 입력한 정보로 로그인 시도 (async: 비동기 작업 처리 의미)
  Future<void> _login() async {
    // 로그인 버튼을 누를 시 현재 열려있는 키보드를 닫음
    FocusScope.of(context).unfocus();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('이메일과 비밀번호를 입력해주세요.');
      return;
    }
    if (!_isValidEmail(email)) {
      _showErrorDialog('올바른 이메일 형식을 입력해주세요.');
      return;
    }
    setState(() {
      // 로딩 상태 true로 변경 및 UI 갱신 -> 로딩 인디케이터 표시
      _isLoading = true;
    });

    // api.dart 에서 ApiService의 login 함수 호출하여 실제 서버에 로그인 요청
    // (api.dart에서 API 경로, 요청/응답 형식 확인 필요)
    Map<String, dynamic> result;
    try {
      result = await AuthApi.login(email: email, password: password);
    } catch (e) {
      // 예기치 못한 예외가 발생하면 로딩 상태 해제 및 에러 표시
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('네트워크 오류가 발생했습니다. 연결을 확인해 주세요.');
      }
      return;
    }

    // API 응답 도착 후 위젯이 현재 화면에 없을 경우 종료(mounted == false인 경우)
    if (!mounted) return;

    // API 응답 도착 후 위젯이 현재 화면에 있는 경우 실행
    setState(() {
      _isLoading = false; // UI 갱신
    });

    if (result['success']) {
      final user = result['data']?['user'];
      final token = result['data']?['token'];
      if (token != null) {
        await ApiService.saveToken(token);
      }

      if (user != null && user['nickname'] != null && user['name'] != null) {
        await ApiService.saveUserInfo(
          nickname: user['nickname'],
          name: user['name'],
        );
      }

      // FCM 토큰 서버 동기화 (로그인 직후)
      print('[Login] 로그인 성공 - FCM 토큰 동기화 시작');
      await NotificationService.syncFcmTokenWithServer(force: true);
      print('[Login] FCM 상태: ${NotificationService.isFcmEnabled ? "활성화됨 ✅" : "비활성화됨 ⚠️"}');

      if (mounted) {
        // 로그인 성공시 로그인 화면으로 돌아갈 수 없도록 MainPage로 화면 교체
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      // api.dart의 ApiService에서 반환된 에러 메세지 사용자에게 보여줌
      // (서버 응답의 에러 메세지 키가 'message'가 아닌 경우 ApiService에서 수정 필요)
      await ApiService.deleteToken();
      _showErrorDialog(result['message']);
    }
  }

  // 사용자에게 알림 or 에러메세지 보여주는 다이얼로그 위젯
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 화면 상단의 로고, 앱 제목, 부제목 UI 생성
  Widget _buildLogoAndTitle() {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: const Icon(
            Icons.restaurant_menu,
            size: 100,
            color: Color(0xFF81C784),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '밥동무',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A3A52),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '함께하는 즐거운 식사',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 이메일(ID), 비밀번호 입력창과 아이디/비밀번호 찾기 UI 생성
  Widget _buildFormFields() {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            _passwordFocusNode.requestFocus();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            prefixIcon: const Icon(Icons.email_outlined),
            hintText: 'ID(이메일)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            _login();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            prefixIcon: const Icon(Icons.lock_outlined),
            hintText: '비밀번호',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            // TODO: '아이디/비밀번호 찾기' 버튼 눌렀을 때의 동작 구현 필요
            child: const Text(
              '아이디/비밀번호 찾기',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  // 로그인, 회원가입 등 주요 액션 버튼 UI 생성
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81C784),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '로그인',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('계정이 없으신가요? ', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: const Text(
                '회원가입',
                style: TextStyle(
                  color: Color(0xFF81C784),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  // 최종 UI 구성 및 반환하는 메인 메서드
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                // 실제로 위젯이 그려질 수 있는 영역의 크기를 정확히 계산
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      // SingleChildScrollView + BoxConstraints 조합을 통해 키보드가 올라와도 UI가 잘리지 않고 스크롤 되고 콘텐츠가 적어도 화면 전체 높이를 채우도록 함
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLogoAndTitle(),
                            const SizedBox(height: 50),
                            _buildFormFields(),
                            const SizedBox(height: 20),
                            _buildActionButtons(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
