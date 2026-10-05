import '../services/api.dart';

/// URL 관련 유틸리티 클래스
/// 슬래시 중복 방지 및 전체 URL 생성
class UrlUtils {
  /// 이미지 전체 URL 생성기
  ///
  /// 서버에서 받은 상대 경로를 완전한 URL로 변환합니다.
  /// Relative upload paths are resolved against the configured API base URL.
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return ""; // 혹은 기본 이미지 URL 리턴
    }

    // 이미 완전한 URL인 경우 (http로 시작)
    if (imagePath.startsWith("http")) {
      return imagePath;
    }

    // baseUrl 가져오기
    final baseUrl = ApiService.baseUrl;

    // baseUrl의 끝에 '/'가 있는지 확인
    String cleanBaseUrl = baseUrl.endsWith("/")
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    // imagePath의 시작에 '/'가 있는지 확인
    String cleanPath = imagePath.startsWith("/") ? imagePath : "/$imagePath";

    // 깔끔하게 합쳐서 리턴
    return "$cleanBaseUrl$cleanPath";
  }

  /// 일반 API 경로 생성기
  ///
  /// API 엔드포인트 경로를 완전한 URL로 변환합니다.
  static String getApiUrl(String? apiPath) {
    if (apiPath == null || apiPath.isEmpty) {
      return ApiService.baseUrl;
    }

    // 이미 완전한 URL인 경우
    if (apiPath.startsWith("http")) {
      return apiPath;
    }

    final baseUrl = ApiService.baseUrl;

    String cleanBaseUrl = baseUrl.endsWith("/")
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    String cleanPath = apiPath.startsWith("/") ? apiPath : "/$apiPath";

    return "$cleanBaseUrl$cleanPath";
  }
}
