import 'dart:async';
import 'dart:convert'; // JSON을 다루기 위한 라이브러리
import 'package:http/http.dart' as http; // HTTP 통신을 위한 라이브러리
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery/utils/logging.dart';
import '../dummy_data/dummy.dart';

export 'auth_api.dart';
export 'post_api.dart';
export 'chat_api.dart';
export 'user_api.dart';
export 'shared_cart_api.dart';
export 'joint_order_api.dart';
export 'room_order_api.dart';
export 'place_search_api.dart';

/// 공통 API 관리

class ApiService {
  // Mock mode is opt-in; never use test data or a remote server by default.
  static const bool isDevelopment = bool.fromEnvironment(
    'APP_USE_MOCK_DATA',
    defaultValue: false,
  );
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.invalid',
  );
  static String? _sessionToken;
  static String? _sessionUserId;
  static String? _sessionNickname;
  static String? _sessionName;
  static bool _legacySessionCleared = false;
  // 네트워크 요청 타임아웃
  static const Duration _timeout = Duration(seconds: 10);

  static Uri uriFor(String endpoint) {
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedEndpoint = endpoint.replaceFirst(RegExp(r'^/+'), '');
    final uri = Uri.parse('$normalizedBase/$normalizedEndpoint');
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'API_BASE_URL must be an HTTPS origin without credentials or query data.',
      );
    }
    return uri;
  }

  /// GET 요청을 처리하는 공통 메서드
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      final response = await http
          .get(
            uriFor(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
              //인증 방식에 맞춰 헤더 수정 필요(e.g. 'Authorization': 'Token $token' / 'Autho': '$token')
            },
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// POST 요청을 처리하는 공통 메서드
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic>? body, {
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      final response = await http
          .post(
            uriFor(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
              // get요청과 동일하게 인증 방식에 맞춰 수정 필요
            },
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// PUT 요청을 처리하는 공통 메서드
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      final response = await http
          .put(
            uriFor(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// DELETE 요청을 처리하는 공통 메서드
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = false,
    Map<String, dynamic>? body,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      final response = await http
          .delete(
            uriFor(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Multipart/form-data 요청 (파일 업로드)
  static Future<Map<String, dynamic>> multipartPost(
    String endpoint, {
    required String filePath,
    required String fileField,
    Map<String, String>? fields,
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      final uri = uriFor(endpoint);
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (fields != null) {
        request.fields.addAll(fields);
      }

      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// HTTP 응답을 처리하는 공통 메서드
  static Map<String, dynamic> _handleResponse(http.Response response) {
    logDebug('[ApiService DEBUG] Response status code: ${response.statusCode}');
    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 202) {
      try {
        final parsed = json.decode(response.body);
        if (parsed is Map<String, dynamic>) {
          final result = <String, dynamic>{
            'success': parsed['success'] ?? true,
            'data': parsed.containsKey('data') ? parsed['data'] : parsed,
          };
          if (parsed.containsKey('message')) {
            result['message'] = parsed['message'];
          }
          if (parsed.containsKey('meta')) {
            result['meta'] = parsed['meta'];
          }
          return result;
        }
        return {'success': true, 'data': parsed};
      } catch (_) {
        return {'success': false, 'message': '서버 응답을 처리하지 못했습니다.'};
      }
    } else if (response.statusCode == 204) {
      // 성공이지만 본문이 없는 경우 (DELETE 등)
      return {'success': true, 'data': null};
    } else {
      final errorBody = response.body;
      String message = '서버 오류: ${response.statusCode}';

      if (errorBody.isNotEmpty) {
        try {
          final parsed = json.decode(errorBody);
          if (parsed is Map<String, dynamic>) {
            final serverMessage = parsed['message'] ?? parsed['error'];
            if (serverMessage is String && serverMessage.isNotEmpty) {
              message = serverMessage;
            }
          }
        } catch (_) {
          // 본문이 JSON이 아니거나 파싱 실패한 경우 원문 유지
        }
      }

      return {
        'success': false,
        'message': message,
        'statusCode': response.statusCode,
      };
    }
  }

  /// 네트워크 에러를 처리하는 공통 메서드
  static Map<String, dynamic> _handleError(dynamic error) {
    logDebug('API request failed (${error.runtimeType})');
    return {'success': false, 'message': '네트워크 연결을 확인해 주세요.'};
  }

  static void cacheDeliveryFeeInfo({
    required String roomId,
    required int deliveryFee,
    int? deliveryFeePerPerson,
  }) {
    DummyDataCache.tempDeliveryFeeInfo[roomId] = {
      'deliveryFee': deliveryFee,
      if (deliveryFeePerPerson != null && deliveryFeePerPerson > 0)
        'deliveryFeePerPerson': deliveryFeePerPerson,
    };
  }

  static Map<String, int>? getDeliveryFeeInfo(String roomId) {
    return DummyDataCache.tempDeliveryFeeInfo[roomId];
  }

  // 로딩, 성공, 실패의 UI 상태 관리를 포함하여 리스트 조회 API를 호출
  static Future<void> fetchWithState<T>({
    required Future<Map<String, dynamic>> Function() apiCall,
    required void Function(bool) setLoading,
    required void Function(List<T>) onSuccess,
    required void Function(String) onError,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    setLoading(true);

    try {
      final result = await apiCall();

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        final List<T> items = data
            .map((json) => fromJson(json as Map<String, dynamic>))
            .toList();
        onSuccess(items);
      } else {
        onError(result['message'] ?? '알 수 없는 오류가 발생했습니다');
      }
    } catch (e) {
      onError('네트워크 오류가 발생했습니다');
    } finally {
      setLoading(false);
    }
  }

  // 토큰 관리
  static Future<void> saveToken(String token) async {
    await _clearLegacySessionData();
    _sessionToken = token;
  }

  static Future<String?> getToken() async {
    await _clearLegacySessionData();
    return _sessionToken;
  }

  static Future<void> deleteToken() async {
    _sessionToken = null;
    _sessionUserId = null;
    _sessionNickname = null;
    _sessionName = null;
    await _clearLegacySessionData();
  }

  static Future<void> _clearLegacySessionData() async {
    if (_legacySessionCleared) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_nickname');
    await prefs.remove('user_name');
    _legacySessionCleared = true;
  }

  static Future<void> initializeSessionStorage() => _clearLegacySessionData();

  // Session data remains in memory and is cleared when the app process exits.
  static Future<void> saveUserInfo({
    required String nickname,
    required String name,
  }) async {
    await _clearLegacySessionData();
    _sessionNickname = nickname;
    _sessionName = name;
  }

  // 사용자 ID 저장
  static Future<void> saveUserId(String userId) async {
    await _clearLegacySessionData();
    _sessionUserId = userId;
  }

  static Future<String?> getUserId() async {
    await _clearLegacySessionData();
    return _sessionUserId;
  }

  // 사용자 닉네임 조회
  static Future<String?> getUserNickname() async {
    await _clearLegacySessionData();
    return _sessionNickname;
  }

  // 사용자 이름 조회
  static Future<String?> getUserName() async {
    await _clearLegacySessionData();
    return _sessionName;
  }

  // 사용자 정보 삭제 (로그아웃 시 호출)
  static Future<void> deleteUserInfo() async {
    _sessionNickname = null;
    _sessionName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_nickname');
    await prefs.remove('user_name');
  }

  // 사용자 ID 삭제 (로그아웃 시 호출)
  static Future<void> deleteUserId() async {
    _sessionUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
  }

  /// JWT access token에서 사용자 ID를 추출
  static String? getUserIdFromTokenValue(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      final normalizedPayload = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
      final payload = json.decode(payloadJson);
      final dynamic rawId = (payload is Map<String, dynamic>)
          ? payload['sub'] ?? payload['userId'] ?? payload['id']
          : null;
      if (rawId == null) {
        return null;
      }
      return rawId.toString();
    } catch (_) {
      return null;
    }
  }
}
