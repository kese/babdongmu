import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Form 위젯의 상태에 접근하여 유효성 검사, 각 필드의 값을 저장하는 등의 작업 가능
  final _formKey = GlobalKey<FormState>();
  // textformfield의 텍스트 제어 및 사용자가 입력한 값을 가져오기 위한 컨트롤러들
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController(); // 비밀번호 확인 컨트롤러
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();

  // API 호출 중 로딩 인디케이터 화면 표시 여부를 결정하는 상태 변수
  bool _isLoading = false;

  // 비밀번호 보이기/숨기기 상태 관리 변수 (true: 숨김(default),false: 보임)
  bool _isPasswordObscured = true;
  // 비밀번호 확인 필드용 별도 상태 변수
  // 비밀번호와 비밀번호 확인 필드를 독립적으로 제어하기 위해 별도로 분리
  bool _isPasswordConfirmObscured = true;

  // 프로필 이미지
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();


  String? _normalizePhoneNumber(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;

    if (trimmed.startsWith('+')) {
      return '+$digitsOnly';
    }

    if (digitsOnly.startsWith('0')) {
      final withoutLeadingZero = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
      if (withoutLeadingZero.isEmpty) return null;
      return '+82$withoutLeadingZero';
    }

    return '+$digitsOnly';
  }

  @override
  void dispose() {
    // 위젯이 화면에서 사라질 때 호출
    // 메모리 누수 방지
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose(); // 컨트롤러 정리
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // 이메일 형식 유효성 검사를 위한 헬퍼 함수
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 비밀번호 유효성 검사 헬퍼 함수
  // 영문, 숫자, 특수문자가 모두 포함되고 8자 이상인지 검사
  bool _isValidPassword(String password) {
    final passwordRegex = RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$',
    );
    return passwordRegex.hasMatch(password);
  }

  // 이미지 선택 옵션 표시
  Future<void> _showImageSourceDialog() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 이미지 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF81C784),
              ),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF81C784)),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (source != null) {
      _pickImage(source);
    }
  }

  // 이미지 선택
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showWarning('이미지를 선택하는 중 오류가 발생했습니다');
    }
  }

  // 이미지 제거
  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  // 실제 회원가입 API 호출 비동기 함수
  // _trySignUp에서 유효성 검사를 통과한 후에만 호출됨
  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1단계: 프로필 이미지 업로드 (선택된 경우)
      // 회원가입 전에 이미지를 먼저 업로드하고 URL을 받아옴 (인증 불필요 API)
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        final imageResult = await AuthApi.uploadSignupProfileImage(
          imagePath: _selectedImage!.path,
        );

        if (imageResult['success'] == true && imageResult['data'] != null) {
          uploadedImageUrl = imageResult['data']['image_url'];
        } else {
          // 이미지 업로드 실패 시 경고 표시 후 계속 진행 (이미지 없이 가입)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('프로필 이미지 업로드 실패. 이미지 없이 가입합니다.')),
            );
          }
        }
      }

      // 2단계: 회원가입 요청 (업로드된 이미지 URL 포함)
      final formattedPhone = _normalizePhoneNumber(_phoneController.text);
      if (formattedPhone != null &&
          formattedPhone != _phoneController.text.trim()) {
        _phoneController.text = formattedPhone;
      }

      final result = await AuthApi.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _nameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        address: null,
        phoneNumber: formattedPhone,
        account: null,
        profileImage: uploadedImageUrl, // 업로드된 이미지 URL 전달
      );

      // API 응답 도착 후 위젯이 현재 화면에 없을 경우 종료(mounted == false인 경우)
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      if (result['success']) {
        _showSuccessDialog();
      } else {
        // api.dart의 ApiService에서 반환된 에러 메세지 사용자에게 보여줌
        // 서버 응답의 에러 메세지 키가 'message'가 아닌 경우 ApiService에서 수정 필요
        _showWarning(result['message']);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showWarning('회원가입 중 오류가 발생했습니다');
    }
  }

  // 가입하기 버튼을 눌렀을때 호출되는 함수
  // Form의 유효성을 먼저 검사한 뒤 모든 필드가 유효할때만 실제 가입 로직(_signUp) 호출
  void _trySignUp() {
    FocusScope.of(context).unfocus(); //키보드 닫음
    // Form 안의 모든 TextFormField들의 validator함수 실행 후 하나라도 오류 메세지 반환 시 false 반환
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return; // Form이 유효하지 않으면 즉시 종료
    _signUp(); // 모든 검사 통과 후 실제 회원가입 함수 호출
  }

  // 사용자에게 경고 또는 입력 오류 메세지 보여주는 다이얼로그
  void _showWarning(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('입력 오류'),
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

  // 회원가입 성공시 사용자에게 회원가입 완료를 알리는 다이얼로그
  void _showSuccessDialog() {
    // 확인 버튼을 누르면 다이얼로그와 회원가입 페이지를 모두 닫고 이전 화면으로 돌아감(로그인 화면)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가입 완료'),
        content: const Text('요청이 처리되었습니다. 가입된 계정이면 로그인해 주세요.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  // 최종 UI 구성 및 반환하는 메인 메서드
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '회원가입',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildLabel('이메일', true),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('이메일 주소'),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '이메일을 입력해주세요.';
                          }
                          if (!_isValidEmail(value.trim())) {
                            return '올바른 이메일 형식을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('비밀번호', true),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isPasswordObscured, //동적으로 제어
                        decoration: _inputDecoration('영문, 숫자, 특수문자 포함 8글자 이상')
                            .copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordObscured
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    //아이콘을 누를 때마다 상태 반전(ture <-> false) 및 화면 다시 그려 UI 업데이트
                                    _isPasswordObscured = !_isPasswordObscured;
                                  });
                                },
                              ),
                            ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '비밀번호를 입력해주세요.';
                          }
                          if (value.trim().length < 8) {
                            return '비밀번호는 8자 이상이어야 합니다.';
                          }
                          if (!_isValidPassword((value.trim()))) {
                            return '영문, 숫자, 특수문자를 모두 포함해야 합니다.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('비밀번호 확인', true),
                      TextFormField(
                        controller: _passwordConfirmController,
                        obscureText: _isPasswordConfirmObscured,
                        decoration: _inputDecoration('비밀번호를 다시 한번 입력해주세요')
                            .copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordConfirmObscured
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordConfirmObscured =
                                        !_isPasswordConfirmObscured;
                                  });
                                },
                              ),
                            ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '비밀번호 확인을 입력해주세요.';
                          }
                          if (value != _passwordController.text) {
                            return '비밀번호가 일치하지 않습니다.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('이름', true),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('실명을 입력해주세요.'),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '이름을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('닉네임', true),
                      TextFormField(
                        controller: _nicknameController,
                        decoration: _inputDecoration('앱에서 사용할 닉네임'),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '닉네임을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('전화번호', false),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration('전화번호 (선택)'),
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('프로필 이미지', false),
                      _buildProfileImagePicker(),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _trySignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF81C784),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '가입하기',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // 입력창 위의 라벨 UI(e.g. 비밀번호 *)를 생성하는 헬퍼 메서드
  Widget _buildLabel(String text, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (required) const Text(' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  // TextFormField의 디자인(Decoration)을 통일성 있게 생성하는 헬퍼 메서드
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  // 프로필 이미지 선택 영역 UI 생성 헬퍼 메서드
  Widget _buildProfileImagePicker() {
    final hasImage = _selectedImage != null;

    return GestureDetector(
      onTap: hasImage ? null : _showImageSourceDialog,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: hasImage
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 150,
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _showImageSourceDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _removeImage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 50,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '파일 선택 또는 드래그 앤 드롭',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'PNG, JPG, GIF up to 10MB',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
