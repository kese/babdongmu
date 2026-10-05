// 사용자/프로필 관련 API 관리
import 'package:delivery/dummy_data/dummy.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'dart:convert';
import 'api.dart';
import '../utils/logging.dart';
import 'notification_service.dart';

class UserApi {
  /// 현재 로그인한 사용자 이메일 설정 (개발모드용)
  static void setCurrentUser(String email) {
    DummyUserStore.setCurrentUser(email);
  }

  /// 현재 로그인한 사용자 정보 가져오기 (개발모드용)
  static Map<String, dynamic>? _getCurrentUserData() {
    return DummyUserStore.getCurrentUserData(DummyAuthStore.tempUsers);
  }

  /// 사용자 프로필 정보 가져오기
  static Future<Map<String, dynamic>> getUserProfile() async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      final userData = _getCurrentUserData();
      if (userData == null) {
        return {'success': false, 'message': '로그인된 사용자 정보를 찾을 수 없습니다'};
      }

      logDebug('[UserApi] Mock profile loaded');
      return {
        'success': true,
        'data': {...userData},
      };
    }

    // 실제 API 호출
    return await ApiService.get('api/user/profile', requiresAuth: true);
  }

  /// 사용자 프로필 정보 수정
  static Future<Map<String, dynamic>> updateUserProfile({
    String? name,
    String? phone,
    String? email,
    String? nickname,
    String? address,
    String? account,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));

      if (DummyUserStore.currentUserEmail == null) {
        return {'success': false, 'message': '로그인된 사용자를 찾을 수 없습니다'};
      }

      // 마스터 계정인 경우
      if (DummyUserStore.currentUserEmail == 'portfolio-owner@example.invalid') {
        if (name != null) DummyUserStore.masterUserProfile['name'] = name;
        if (phone != null) DummyUserStore.masterUserProfile['phone'] = phone;
        if (email != null) DummyUserStore.masterUserProfile['email'] = email;
        if (nickname != null)
          DummyUserStore.masterUserProfile['nickname'] = nickname;
        if (address != null)
          DummyUserStore.masterUserProfile['address'] = address;
        if (account != null)
          DummyUserStore.masterUserProfile['account'] = account;

        logDebug('[UserApi DEBUG] (Dev) 마스터 계정 프로필 업데이트 완료');
        return {
          'success': true,
          'message': '프로필이 수정되었습니다',
          'data': {...DummyUserStore.masterUserProfile},
        };
      }

      // 일반 사용자인 경우 - AuthApi의 tempUsers에서 찾아서 업데이트
      final tempUsers = DummyAuthStore.tempUsers;
      for (var user in tempUsers) {
        if (user['email'] == DummyUserStore.currentUserEmail) {
          if (name != null) user['name'] = name;
          if (phone != null) user['phone'] = phone;
          if (nickname != null) user['nickname'] = nickname;
          if (address != null) user['address'] = address;
          if (account != null) user['account'] = account;

          logDebug('[UserApi] Mock profile updated');
          return {
            'success': true,
            'message': '프로필이 수정되었습니다',
            'data': {...user},
          };
        }
      }

      return {'success': false, 'message': '사용자 정보를 찾을 수 없습니다'};
    }

    // 실제 API 호출
    return await ApiService.put('api/user/profile', {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (nickname != null) 'nickname': nickname,
      if (address != null) 'address': address,
      if (account != null) 'account': account,
    }, requiresAuth: true);
  }

  /// 배달비 절약 통계 조회
  static Future<Map<String, dynamic>> getDeliveryStats() async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      if (DummyUserStore.currentUserEmail == null) {
        return {'success': false, 'message': '로그인된 사용자를 찾을 수 없습니다'};
      }

      logDebug('[UserApi DEBUG] (Dev) 배달비 절약 통계 조회');
      return {
        'success': true,
        'data': {
          'total_orders': DummyUserStore.totalOrders,
          'total_delivery_fee_saved': DummyUserStore.totalDeliveryFeeSaved,
          'total_delivery_fee_paid': DummyUserStore.totalDeliveryFeePaid,
          'original_delivery_fee': DummyUserStore.originalDeliveryFee,
        },
      };
    }

    // 실제 API 호출
    return await ApiService.get('api/user/delivery-stats', requiresAuth: true);
  }

  /// 사용자 포인트 조회
  static Future<Map<String, dynamic>> getUserPoints() async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      if (DummyUserStore.currentUserEmail == null) {
        return {'success': false, 'message': '로그인된 사용자를 찾을 수 없습니다'};
      }

      // 마스터 계정인 경우
      if (DummyUserStore.currentUserEmail == 'portfolio-owner@example.invalid') {
        logDebug('[UserApi] Mock points loaded');
        return {
          'success': true,
          'data': {'points': DummyUserStore.masterUserPoints},
        };
      }

      // 일반 사용자인 경우 - 포인트가 없으면 0으로 초기화
      if (!DummyUserStore.userPointsMap.containsKey(
        DummyUserStore.currentUserEmail,
      )) {
        DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!] = 0;
      }

      final points =
          DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!]!;
      logDebug('[UserApi] Mock points loaded');
      return {
        'success': true,
        'data': {'points': points},
      };
    }

    // 실제 API 호출
    return await ApiService.get('api/user/points', requiresAuth: true);
  }

  /// 포인트 충전
  static Future<Map<String, dynamic>> chargePoints({
    required int amount,
    required String paymentMethod, // 'card', 'bank', 'kakao' 등
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 2));

      if (DummyUserStore.currentUserEmail == null) {
        return {'success': false, 'message': '로그인된 사용자를 찾을 수 없습니다'};
      }

      // 마스터 계정인 경우
      if (DummyUserStore.currentUserEmail == 'portfolio-owner@example.invalid') {
        DummyUserStore.masterUserPoints += amount;
        logDebug('[UserApi] Mock points charged');
        return {
          'success': true,
          'message': '$amount 포인트가 충전되었습니다',
          'data': {
            'points': DummyUserStore.masterUserPoints,
            'charged_amount': amount,
          },
        };
      }

      // 일반 사용자인 경우
      if (!DummyUserStore.userPointsMap.containsKey(
        DummyUserStore.currentUserEmail,
      )) {
        DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!] = 0;
      }
      DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!] =
          DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!]! +
          amount;

      logDebug('[UserApi] Mock points charged');
      return {
        'success': true,
        'message': '$amount 포인트가 충전되었습니다',
        'data': {
          'points':
              DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!],
          'charged_amount': amount,
        },
      };
    }

    // 실제 API 호출
    return await ApiService.post('api/user/points/charge', {
      'amount': amount,
      'payment_method': paymentMethod,
    }, requiresAuth: true);
  }

  /// 포인트 출금
  static Future<Map<String, dynamic>> withdrawPoints({
    required int amount,
    required String account, // 계좌번호
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 2));

      if (DummyUserStore.currentUserEmail == null) {
        return {'success': false, 'message': '로그인된 사용자를 찾을 수 없습니다'};
      }

      // 마스터 계정인 경우
      if (DummyUserStore.currentUserEmail == 'portfolio-owner@example.invalid') {
        if (DummyUserStore.masterUserPoints < amount) {
          return {'success': false, 'message': '포인트가 부족합니다'};
        }
        DummyUserStore.masterUserPoints -= amount;
        logDebug('[UserApi] Mock points withdrawn');
        return {
          'success': true,
          'message': '$amount 포인트가 출금되었습니다',
          'data': {
            'points': DummyUserStore.masterUserPoints,
            'withdrawn_amount': amount,
          },
        };
      }

      // 일반 사용자인 경우
      if (!DummyUserStore.userPointsMap.containsKey(
        DummyUserStore.currentUserEmail,
      )) {
        DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!] = 0;
      }

      if (DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!]! <
          amount) {
        return {'success': false, 'message': '포인트가 부족합니다'};
      }

      DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!] =
          DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!]! -
          amount;

      logDebug('[UserApi] Mock points withdrawn');
      return {
        'success': true,
        'message': '$amount 포인트가 출금되었습니다',
        'data': {
          'points':
              DummyUserStore.userPointsMap[DummyUserStore.currentUserEmail!],
          'withdrawn_amount': amount,
        },
      };
    }

    // 실제 API 호출
    return await ApiService.post('api/user/points/withdraw', {
      'amount': amount,
      'account': account,
    }, requiresAuth: true);
  }

  /// 비밀번호 변경
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));

      // 간단한 검증만 수행
      if (currentPassword.length < 8 || newPassword.length < 8) {
        return {'success': false, 'message': '비밀번호는 8자 이상이어야 합니다'};
      }

      logDebug('[UserApi DEBUG] (Dev) 비밀번호 변경 완료');
      return {'success': true, 'message': '비밀번호가 변경되었습니다'};
    }

    // 실제 API 호출
    return await ApiService.put('api/user/password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    }, requiresAuth: true);
  }

  /// 프로필 이미지 업로드 (multipart/form-data)
  static Future<Map<String, dynamic>> uploadProfileImage({
    required String imagePath,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));

      if (DummyUserStore.currentUserEmail == null) {
        return {'success': false, 'message': '로그인된 사용자를 찾을 수 없습니다'};
      }

      // 마스터 계정인 경우
      if (DummyUserStore.currentUserEmail == 'portfolio-owner@example.invalid') {
        DummyUserStore.masterUserProfile['profile_image'] = imagePath;
        logDebug('[UserApi] Mock profile image updated');
        return {
          'success': true,
          'message': '프로필 이미지가 업로드되었습니다',
          'data': {'image_url': imagePath},
        };
      }

      // 일반 사용자인 경우
      final tempUsers = DummyAuthStore.tempUsers;
      for (var user in tempUsers) {
        if (user['email'] == DummyUserStore.currentUserEmail) {
          user['profile_image'] = imagePath;
          logDebug('[UserApi] Mock profile image updated');
          return {
            'success': true,
            'message': '프로필 이미지가 업로드되었습니다',
            'data': {'image_url': imagePath},
          };
        }
      }

      return {'success': false, 'message': '사용자 정보를 찾을 수 없습니다'};
    }

    // 실제 API 호출 - multipart/form-data 방식
    try {
      final uri = ApiService.uriFor('api/user/profile/image');

      // MultipartRequest 생성
      final request = http.MultipartRequest('POST', uri);

      // 인증 토큰 추가
      final token = await ApiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

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
        return responseData;
      } else {
        logDebug('[UserApi] 프로필 이미지 업로드 실패: ${response.statusCode}');
        return {'success': false, 'message': '이미지 업로드에 실패했습니다'};
      }
    } catch (e) {
      logDebug('[UserApi] Profile image upload failed (${e.runtimeType})');
      return {'success': false, 'message': '이미지 업로드 중 오류가 발생했습니다'};
    }
  }

  /// 회원 탈퇴
  static Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));

      // 토큰 및 사용자 정보 삭제
      await ApiService.deleteToken();

      // 현재 사용자 초기화
      DummyUserStore.currentUserEmail = null;

      logDebug('[UserApi DEBUG] (Dev) 회원 탈퇴 완료');
      return {'success': true, 'message': '회원 탈퇴가 완료되었습니다'};
    }

    // 실제 API 호출
    final result = await ApiService.delete(
      'api/user/account',
      requiresAuth: true,
    );

    // 탈퇴 성공 시 로컬 토큰 삭제
    if (result['success'] == true) {
      await NotificationService.unregisterToken();
      await ApiService.deleteToken();
    }

    return result;
  }

  /// 로그아웃
  static Future<Map<String, dynamic>> logout() async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      // 토큰 및 사용자 정보 삭제
      await NotificationService.unregisterToken();
      await ApiService.deleteToken();
      JointOrderApi.resetPendingRequestsCache();

      // 현재 사용자 초기화
      DummyUserStore.currentUserEmail = null;

      logDebug('[UserApi DEBUG] (Dev) 로그아웃 완료');
      return {'success': true, 'message': '로그아웃되었습니다'};
    }

    // 실제 API 호출
    final result = await ApiService.post(
      'api/user/logout',
      {},
      requiresAuth: true,
    );

    // 로그아웃 성공 여부와 관계없이 로컬 토큰은 삭제
    await NotificationService.unregisterToken();
    await ApiService.deleteToken();
    JointOrderApi.resetPendingRequestsCache();

    return result;
  }

  // 디버깅용: 현재 임시 데이터 출력
  static void printTempUserData() {
    DummyUserStore.printTempUserData();
  }
}
