import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delivery/utils/logging.dart';
import '../services/api.dart';
import '../models/user_data.dart';

/// 내 정보 수정 페이지
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // 컨트롤러
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController(); // 현재 비밀번호
  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialLoading = true;

  // 비밀번호 보이기/숨기기
  bool _isCurrentPasswordObscured = true;
  bool _isNewPasswordObscured = true;
  bool _isNewPasswordConfirmObscured = true;

  // 프로필 이미지
  File? _selectedImage;
  String? _currentImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // 사용자 정보 불러오기
  Future<void> _loadUserData() async {
    setState(() => _isInitialLoading = true);

    try {
      final result = await UserApi.getUserProfile();

      if (!mounted) return;

      if (result['success'] == true) {
        final user = User.fromJson(result['data']);
        setState(() {
          _emailController.text = user.email;
          _nameController.text = user.name;
          _nicknameController.text = user.nickname;
          _phoneController.text = user.phone;
          _currentImageUrl = user.profileImage;
        });
      } else {
        logDebug('[EditProfilePage] Profile load failed');
        _showError(result['message'] ?? '사용자 정보를 불러올 수 없습니다');
      }
    } catch (e) {
      logDebug('Profile load failed (${e.runtimeType})');
      if (!mounted) return;
      _showError('정보를 불러오는 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  // 비밀번호 유효성 검사
  bool _isValidPassword(String password) {
    final passwordRegex = RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$',
    );
    return passwordRegex.hasMatch(password);
  }

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
      logDebug('Profile image selection failed (${e.runtimeType})');
      if (!mounted) return;
      _showError('이미지를 선택하는 중 오류가 발생했습니다');
    }
  }

  // 이미지 제거
  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _currentImageUrl = null;
    });
  }

  // 정보 수정 제출
  Future<void> _submitUpdate() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    setState(() => _isLoading = true);
    logDebug('[EditProfilePage] 프로필 업데이트 시작');

    try {
      // 프로필 이미지 업로드 (선택된 이미지가 있는 경우)
      if (_selectedImage != null) {
        logDebug('[EditProfilePage] 프로필 이미지 업로드 시작');
        final imageResult = await UserApi.uploadProfileImage(
          imagePath: _selectedImage!.path,
        );

        if (imageResult['success'] != true) {
          logDebug('[EditProfilePage] Profile image upload failed');
          if (!mounted) return;
          _showError(imageResult['message'] ?? '프로필 이미지 업로드에 실패했습니다');
          setState(() => _isLoading = false);
          return;
        }

        // 업로드 성공 시 현재 이미지 URL 업데이트
        if (imageResult['data'] != null &&
            imageResult['data']['image_url'] != null) {
          _currentImageUrl = imageResult['data']['image_url'];
        }
      }

      // 비밀번호 변경이 필요한 경우
      if (_newPasswordController.text.trim().isNotEmpty) {
        // 현재 비밀번호 필수 검증
        if (_currentPasswordController.text.trim().isEmpty) {
          if (!mounted) return;
          _showError('비밀번호를 변경하려면 현재 비밀번호를 입력해주세요.');
          setState(() => _isLoading = false);
          return;
        }

        logDebug('[EditProfilePage] 비밀번호 변경 시작');
        final passwordResult = await UserApi.changePassword(
          currentPassword: _currentPasswordController.text.trim(),
          newPassword: _newPasswordController.text.trim(),
        );

        if (passwordResult['success'] != true) {
          logDebug(
            '[EditProfilePage] 비밀번호 변경 실패: ${passwordResult['message']}',
          );
          if (!mounted) return;
          _showError(passwordResult['message'] ?? '비밀번호 변경에 실패했습니다');
          setState(() => _isLoading = false);
          return;
        }
        logDebug('[EditProfilePage] 비밀번호 변경 완료');
      }

      // 프로필 정보 수정
      final formattedPhone = _normalizePhoneNumber(_phoneController.text);
      if (formattedPhone != null &&
          formattedPhone != _phoneController.text.trim()) {
        _phoneController.text = formattedPhone;
      }

      logDebug('[EditProfilePage] 프로필 정보 업데이트 시작');
      final profileResult = await UserApi.updateUserProfile(
        name: _nameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        phone: formattedPhone,
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      if (profileResult['success'] == true) {
        logDebug('[EditProfilePage] 프로필 정보 업데이트 완료');
        // 사용자 정보 업데이트 (로컬 저장)
        await ApiService.saveUserInfo(
          nickname: _nicknameController.text.trim(),
          name: _nameController.text.trim(),
        );

        _showSuccessDialog();
      } else {
        logDebug(
          '[EditProfilePage] 프로필 정보 업데이트 실패: ${profileResult['message']}',
        );
        _showError(profileResult['message'] ?? '정보 수정에 실패했습니다');
      }
    } catch (e) {
      logDebug('Profile update failed (${e.runtimeType})');
      if (!mounted) return;
      _showError('정보 수정 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 회원 탈퇴 확인
  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('정말로 탈퇴하시겠습니까?\n\n탈퇴하시면 모든 정보가 삭제되며 복구할 수 없습니다.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteAccount();
    }
  }

  // 회원 탈퇴 실행
  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    logDebug('[EditProfilePage] 회원 탈퇴 시작');

    try {
      final result = await UserApi.deleteAccount(password: '');

      if (!mounted) return;

      if (result['success'] == true) {
        logDebug('[EditProfilePage] 회원 탈퇴 완료');
        // 탈퇴 완료 다이얼로그 표시
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('탈퇴 완료'),
            content: const Text('회원 탈퇴가 완료되었습니다.\n그동안 이용해 주셔서 감사합니다.'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 다이얼로그 닫기
                  // 로그인 화면으로 이동
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text(
                  '확인',
                  style: TextStyle(color: Color(0xFF81C784)),
                ),
              ),
            ],
          ),
        );
      } else {
        logDebug('[EditProfilePage] Account deletion failed');
        _showError(result['message'] ?? '회원 탈퇴에 실패했습니다');
      }
    } catch (e) {
      logDebug('Account deletion failed (${e.runtimeType})');
      if (!mounted) return;
      _showError('회원 탈퇴 중 오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('완료'),
        content: const Text('정보가 수정되었습니다.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // 내 정보 수정 페이지도 닫기
            },
            child: const Text('확인', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
      ),
    );
  }

  @override
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
        title: const Text(
          '내 정보 수정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isInitialLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF81C784)),
            )
          : SafeArea(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF81C784),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '내 정보를 수정하세요',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // 이메일 (읽기 전용)
                            _buildLabel('이메일', true),
                            TextFormField(
                              controller: _emailController,
                              enabled: false,
                              decoration: _inputDecoration(
                                '이메일 주소',
                              ).copyWith(fillColor: Colors.grey[200]),
                            ),
                            const SizedBox(height: 20),

                            // 현재 비밀번호 (비밀번호 변경 시 필수)
                            _buildLabel('현재 비밀번호', false),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: _isCurrentPasswordObscured,
                              decoration: _inputDecoration('비밀번호 변경 시 필수 입력')
                                  .copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isCurrentPasswordObscured
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isCurrentPasswordObscured =
                                              !_isCurrentPasswordObscured;
                                        });
                                      },
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 20),

                            // 새 비밀번호
                            _buildLabel('새 비밀번호', false),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _isNewPasswordObscured,
                              decoration:
                                  _inputDecoration(
                                    '영문, 숫자, 특수문자 포함 8글자 이상',
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isNewPasswordObscured
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isNewPasswordObscured =
                                              !_isNewPasswordObscured;
                                        });
                                      },
                                    ),
                                  ),
                              validator: (value) {
                                // 비밀번호 필드가 비어있으면 검증하지 않음
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                if (value.trim().length < 8) {
                                  return '비밀번호는 8자 이상이어야 합니다.';
                                }
                                if (!_isValidPassword(value.trim())) {
                                  return '영문, 숫자, 특수문자를 모두 포함해야 합니다.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // 새 비밀번호 확인
                            _buildLabel('새 비밀번호 확인', false),
                            TextFormField(
                              controller: _newPasswordConfirmController,
                              obscureText: _isNewPasswordConfirmObscured,
                              decoration: _inputDecoration('비밀번호를 다시 한번 입력해주세요')
                                  .copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isNewPasswordConfirmObscured
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isNewPasswordConfirmObscured =
                                              !_isNewPasswordConfirmObscured;
                                        });
                                      },
                                    ),
                                  ),
                              validator: (value) {
                                // 새 비밀번호가 입력된 경우에만 검증
                                if (_newPasswordController.text
                                    .trim()
                                    .isNotEmpty) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '비밀번호 확인을 입력해주세요.';
                                  }
                                  if (value != _newPasswordController.text) {
                                    return '비밀번호가 일치하지 않습니다.';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // 이름
                            _buildLabel('이름', true),
                            TextFormField(
                              controller: _nameController,
                              decoration: _inputDecoration('실명을 입력해주세요.'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '이름을 입력해주세요.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // 닉네임
                            _buildLabel('닉네임', true),
                            TextFormField(
                              controller: _nicknameController,
                              decoration: _inputDecoration('앱에서 사용할 닉네임'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '닉네임을 입력해주세요.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // 전화번호
                            _buildLabel('전화번호', false),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDecoration('전화번호 (선택)'),
                            ),
                            const SizedBox(height: 20),

                            // 프로필 이미지
                            _buildLabel('프로필 이미지', false),
                            _buildProfileImagePicker(),
                            const SizedBox(height: 40),

                            // 완료 버튼
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitUpdate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81C784),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '완료',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 회원 탈퇴 버튼
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : _confirmDeleteAccount,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.red,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '회원 탈퇴',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
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
      disabledBorder: OutlineInputBorder(
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

  Widget _buildProfileImagePicker() {
    final hasImage = _selectedImage != null || _currentImageUrl != null;

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
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : (_currentImageUrl != null
                                ? Image.network(
                                    _currentImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey[400],
                                        ),
                                      );
                                    },
                                  )
                                : Container()),
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
