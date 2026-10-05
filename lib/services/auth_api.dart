//회원관련 API 관리
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:delivery/utils/logging.dart';
import 'package:delivery/dummy_data/dummy.dart';
import 'api.dart';
import 'notification_service.dart';

class AuthApi {
  /// 회원가입용 프로필 이미지 업로드 API (인증 불필요)
  ///
  /// 회원가입 전에 이미지를 먼저 업로드하고, 반환된 URL을 회원가입 요청에 포함합니다.
  /// 엔드포인트: POST /api/auth/upload-profile-image
  static Future<Map<String, dynamic>> uploadSignupProfileImage({
    required String imagePath,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));

      // 개발 모드: 가상 URL 반환
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fakeUrl = '/uploads/profile/signup_$timestamp.jpg';

      logDebug('[AuthApi] Mock signup image prepared');
      return {
        'success': true,
        'message': '프로필 이미지가 업로드되었습니다',
        'data': {'image_url': fakeUrl},
      };
    }

    // 실제 API 호출 - multipart/form-data 방식 (인증 불필요)
    try {
      final uri = ApiService.uriFor('api/auth/upload-profile-image');

      // MultipartRequest 생성
      final request = http.MultipartRequest('POST', uri);

      // 이미지 파일 추가 (MIME Type 명시)
      final file = File(imagePath);
      final fileName = file.path.split('/').last.split('\\').last;
      final extension = fileName.split('.').last.toLowerCase();

      // 확장자에 따른 MIME Type 결정
      MediaType? contentType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = MediaType('image', 'jpeg');
          break;
        case 'png':
          contentType = MediaType('image', 'png');
          break;
        case 'gif':
          contentType = MediaType('image', 'gif');
          break;
        default:
          contentType = MediaType('image', 'jpeg'); // 기본값
      }

      final multipartFile = await http.MultipartFile.fromPath(
        'image', // 서버에서 받는 필드명
        imagePath,
        filename: fileName,
        contentType: contentType,
      );
      request.files.add(multipartFile);

      // 요청 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // 응답 처리
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        logDebug('[AuthApi] 회원가입용 프로필 이미지 업로드 성공');
        return {
          'success': true,
          'message': responseData['message'] ?? '프로필 이미지가 업로드되었습니다',
          'data':
              responseData['data'] ?? {'image_url': responseData['image_url']},
        };
      } else {
        logDebug('[AuthApi] 회원가입용 프로필 이미지 업로드 실패: ${response.statusCode}');
        return {
          'success': false,
          'message': '이미지 업로드에 실패했습니다 (${response.statusCode})',
        };
      }
    } catch (e) {
      logDebug('Signup profile image upload failed (${e.runtimeType})');
      return {'success': false, 'message': '이미지 업로드 중 오류가 발생했습니다'};
    }
  }

  /// 회원가입 API
  static Future<Map<String, dynamic>> signUp({
    //서버에 회원가입 요청
    required String email,
    required String password,
    required String username,
    required String nickname,
    String? address,
    String? phoneNumber,
    String? account,
    String? profileImage,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));

      // 중복 이메일 체크
      for (var user in DummyAuthStore.tempUsers) {
        if (user['email'] == email) {
          return {'success': false, 'message': '이미 가입된 이메일입니다'};
        }
      }

      // 임시 저장소에 저장
      DummyAuthStore.tempUsers.add({
        'email': email,
        'password': password,
        'username': username,
        'nickname': nickname,
        'address': address ?? '',
        'phoneNumber': phoneNumber ?? '',
        'account': account ?? '',
        'profile_image': profileImage ?? '',
      });

      logDebug('Mock signup completed');
      return {'success': true, 'message': '회원가입 성공'};
    }

    // 실제 API 호출
    final payload = <String, dynamic>{
      'email': email,
      'password': password,
      'username': username,
      'nickname': nickname,
    };

    if (address != null && address.isNotEmpty) {
      payload['address'] = address;
    }
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      payload['phoneNumber'] = phoneNumber;
    }
    if (account != null && account.isNotEmpty) {
      payload['account'] = account;
    }
    if (profileImage != null && profileImage.isNotEmpty) {
      payload['profileImageUrl'] = profileImage; // 서버가 기대하는 필드명
    }

    return await ApiService.post('api/auth/signup', payload);
  }

  /// 로그인 API
  static Future<Map<String, dynamic>> login({
    //서버에 로그인을 요청하고 성공 시 토큰 저장
    required String email,
    required String password,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));

      // 임시 저장소에서 사용자 찾기
      for (var user in DummyAuthStore.tempUsers) {
        if (user['email'] == email && user['password'] == password) {
          final token = 'mock-${DateTime.now().microsecondsSinceEpoch}';
          await ApiService.saveToken(token);
          //로그인 성공 시 사용자 정보도 저장
          await ApiService.saveUserInfo(
            nickname: user['nickname']!,
            name: user['username']!,
          );
          await ApiService.saveUserId(user['email']!); // 일반 계정 ID 저장
          // 현재 로그인한 사용자 이메일 설정 (개발모드용)
          DummyUserStore.setCurrentUser(email);

          logDebug('Mock login completed');

          return {
            'success': true,
            'message': '로그인 성공',
            'data': {
              'token': token,
              'user': {
                'email': email,
                'nickname': user['nickname'],
                'username': user['username'],
              },
            },
          };
        }
      }

      logDebug('Mock login failed');
      return {'success': false, 'message': '이메일 또는 비밀번호가 일치하지 않습니다'};
    }

    // 실제 API 호출
    final result = await ApiService.post('api/auth/login', {
      'email': email,
      'password': password,
    });

    if (result['success'] == true) {
      String? token;
      String? nickname;
      String? username;

      final data = result['data'];
      Map<String, dynamic>? payload;
      if (data is Map<String, dynamic>) {
        payload = data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : data;
      } else if (data is String) {
        token = data;
      }

      if (payload != null) {
        token ??= payload['accessToken'] ?? payload['token'] ?? payload['jwt'];

        final dynamic userRaw = payload['user'] ?? payload['userInfo'];
        if (userRaw is Map<String, dynamic>) {
          nickname = userRaw['nickname']?.toString();
          username =
              userRaw['username']?.toString() ?? userRaw['name']?.toString();
        } else {
          nickname = payload['nickname']?.toString();
          username =
              payload['username']?.toString() ?? payload['name']?.toString();
        }
      }

      if (token != null) {
        await ApiService.saveToken(token);
      } else {
        logDebug('Login response did not include an access token');
      }

      String? resolvedUserId;
      if (payload != null) {
        final dynamic userRaw = payload['user'] ?? payload['userInfo'];
        if (userRaw is Map<String, dynamic>) {
          resolvedUserId =
              userRaw['id']?.toString() ??
              userRaw['userId']?.toString() ??
              userRaw['user_id']?.toString();
        }
        resolvedUserId ??=
            payload['userId']?.toString() ?? payload['user_id']?.toString();
      }
      resolvedUserId ??= ApiService.getUserIdFromTokenValue(token);
      if (resolvedUserId != null) {
        await ApiService.saveUserId(resolvedUserId);
      }

      final profileResult = await UserApi.getUserProfile();
      if (profileResult['success'] == true) {
        final profilePayload = profileResult['data'];
        Map<String, dynamic>? profileData;

        if (profilePayload is Map<String, dynamic>) {
          if (profilePayload['data'] is Map<String, dynamic>) {
            profileData = profilePayload['data'] as Map<String, dynamic>;
          } else {
            profileData = profilePayload;
          }
        }

        if (profileData != null) {
          if (profileData['nickname'] != null &&
              profileData['nickname'].toString().trim().isNotEmpty) {
            nickname = profileData['nickname'].toString();
          }
          if (profileData['name'] != null &&
              profileData['name'].toString().trim().isNotEmpty) {
            username = profileData['name'].toString();
          }
        }
      }

      // 닉네임/이름이 없는 경우에도 기본값으로 저장해 UI 흐름이 끊기지 않도록 함
      await ApiService.saveUserInfo(
        nickname: nickname ?? '사용자',
        name: username ?? '알 수 없음',
      );
      await NotificationService.syncFcmTokenWithServer(force: true);
      JointOrderApi.resetPendingRequestsCache();
    }

    return result;
  }

  // 디버깅
  static void printTempUsers() {
    DummyAuthStore.printUsers();
  }
}
