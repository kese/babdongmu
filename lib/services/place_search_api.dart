import 'dart:convert';

import 'package:delivery/models/place_data.dart';
import 'package:http/http.dart' as http;
import 'api.dart';
import '../utils/logging.dart';

class PlaceSearchApi {
  // [백엔드] 서버 팀에서 정확한 엔드포인트 경로 확인 필요
  // 현재는 일반적인 경로로 설정: /api/v1/places/search
  // GET: ?keyword=검색어 또는 POST: {keyword} 중 선택
  // 응답: [{id, name, address, latitude, longitude}] 또는 {data: [...]})
  static Uri get _endpoint => ApiService.uriFor('api/v1/places/search');
  static Uri get _reverseGeocodeEndpoint =>
      ApiService.uriFor('api/v1/places/reverse-geocode');
  static Uri get _nearbyPoiEndpoint =>
      ApiService.uriFor('api/v1/places/nearby-poi');

  static Future<List<Place>> searchPlace({
    required String keyword,
    PlaceSearchTransport transport = PlaceSearchTransport.query,
    Map<String, dynamic>? extraPayload,
    double? latitude,   // 사용자 현재 위도 (위치 기반 검색)
    double? longitude,  // 사용자 현재 경도 (위치 기반 검색)
  }) async {
    // 개발 모드: 더미 데이터 반환
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _getDummyPlaces(keyword);
    }

    // 실제 서버 API 호출
    final request = _buildRequest(
      keyword: keyword,
      transport: transport,
      extraPayload: extraPayload,
      latitude: latitude,
      longitude: longitude,
    );

    final client = http.Client();
    http.Response response;
    try {
      response = await _sendRequest(client, request);
    } finally {
      client.close();
    }

    if (response.statusCode != 200) {
      throw PlaceSearchException(
        'Failed to fetch place list. status=${response.statusCode}',
      );
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is List) {
      return decoded
          .map(
            (item) => Place.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        return data
            .map(
              (item) => Place.fromJson(
                item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
    }
    throw PlaceSearchException('Unexpected response shape');
  }

  /// 주변 POI 검색: 좌표 -> 상호명 (카카오택시 스타일)
  /// radius 생략 시 서버 기본값(20m) 사용 (§4.3.2)
  static Future<Map<String, String?>> nearbyPoi({
    required double latitude,
    required double longitude,
    int? radius, // 생략 가능 (서버 기본값: 20m)
  }) async {
    // 개발 모드: 더미 POI 반환 (3단계 폴백 전략 시뮬레이션)
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 좌표 기반 케이스 분류 (3단계 폴백 시뮬레이션)
      final hash = ((latitude + longitude) * 1000).toInt().abs() % 10;
      
      // 1단계: 카테고리 검색 성공 (60% 확률 - 음식점/카페)
      if (hash < 6) {
        final pois = [
          {'name': '스타벅스 교통대점', 'category': '카페'},
          {'name': '맘스터치 교통대점', 'category': '음식점'},
          {'name': 'GS25 교통대점', 'category': '편의점'},
          {'name': '이디야커피 교통대점', 'category': '카페'},
          {'name': '한솥도시락 교통대점', 'category': '음식점'},
          {'name': '세븐일레븐 충주점', 'category': '편의점'},
        ];
        final poi = pois[hash];
        logDebug('[PlaceSearchApi] POI result available');
        return {
          'poi': poi['name'],
          'category': poi['category'],
          'address': '충북 충주시 대학로 ${(latitude * 100).toInt() % 100}',
        };
      }
      
      // 2단계: 건물명 (30% 확률 - 아파트/빌라/건물)
      if (hash < 9) {
        final buildings = ['드림빌', '학생회관', '래미안아파트', '교통대오피스텔'];
        final building = buildings[hash - 6];
        logDebug('[PlaceSearchApi] Building result available');
        return {
          'poi': building,
          'category': '건물',
          'address': '충북 충주시 대학로 ${(latitude * 100).toInt() % 100}',
        };
      }
      
      // 3단계: 지역명만 (10% 확률 - 외곽 도로)
      logDebug('[PlaceSearchApi] No POI result');
      return {
        'poi': null,
        'address': '충북 충주시 대소원면 ${(latitude * 100).toInt() % 100}',
      };
    }

    // 서버 API 호출
    try {
      // radius 생략 시 서버 기본값(20m) 자동 적용
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      };
      if (radius != null) {
        queryParams['radius'] = radius.toString();
      }
      
      final uri = _nearbyPoiEndpoint.replace(
        queryParameters: queryParams,
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        
        final poi = decoded['poi'];
        final fallbackAddress = decoded['fallbackAddress'] ?? '';
        
        if (poi != null && poi is Map) {
          // POI 있음
          return {
            'poi': poi['name']?.toString(),
            'category': poi['category']?.toString(),
            'address': fallbackAddress,
          };
        } else {
          // POI 없음
          return {
            'poi': null,
            'address': fallbackAddress,
          };
        }
      } else {
        // 실패 시 역지오코딩으로 fallback
        return {
          'poi': null,
          'address': await reverseGeocode(
            latitude: latitude,
            longitude: longitude,
          ),
        };
      }
    } catch (e) {
      // 오류 시 역지오코딩으로 fallback
      return {
        'poi': null,
        'address': await reverseGeocode(
          latitude: latitude,
          longitude: longitude,
        ),
      };
    }
  }

  /// 역지오코딩: 좌표 -> 주소
  static Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    // 개발 모드: 더미 주소 반환
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));
      return '충북 충주시 대학로 ${(latitude * 100).toInt() % 100}';
    }

    // 좌표 유효성 검증
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw PlaceSearchException('유효하지 않은 좌표입니다.');
    }

    // 서버 API 호출
    try {
      final uri = _reverseGeocodeEndpoint.replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        
        // 형식 1: 객체 직접 반환
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] ?? decoded;
          return data['address'] ??
              data['roadAddress'] ??
              data['road_address'] ??
              '';
        }
        
        return null;
      } else if (response.statusCode == 404) {
        // 주소를 찾을 수 없음 (바다, 외국 등)
        return null;
      } else {
        throw PlaceSearchException(
          'Reverse geocoding failed. status=${response.statusCode}',
        );
      }
    } catch (e) {
      throw PlaceSearchException('역지오코딩에 실패했습니다.');
    }
  }

  /// 개발 모드용 더미 장소 데이터
  static List<Place> _getDummyPlaces(String keyword) {
    // 한국교통대학교 충주캠퍼스 기준 더미 데이터
    final dummyPlaces = [
      {
        'id': '1',
        'name': '$keyword 교통대점',
        'address': '충북 충주시 대학로 50',
        'latitude': 36.9984,
        'longitude': 127.9253,
      },
      {
        'id': '2',
        'name': '$keyword 충주점',
        'address': '충북 충주시 중앙탑면 123',
        'latitude': 36.9910,
        'longitude': 127.9275,
      },
      {
        'id': '3',
        'name': '$keyword 청주점',
        'address': '충북 청주시 흥덕구 456',
        'latitude': 36.6424,
        'longitude': 127.4890,
      },
    ];

    return dummyPlaces
        .map((item) => Place.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<http.Response> _sendRequest(
    http.Client client,
    _PlaceSearchRequest request,
  ) {
    const timeout = Duration(seconds: 10);
    final future = switch (request.method) {
      'GET' => client.get(request.uri, headers: request.headers),
      'POST' => client.post(
          request.uri,
          headers: request.headers,
          body: request.body,
        ),
      'PUT' => client.put(
          request.uri,
          headers: request.headers,
          body: request.body,
        ),
      'DELETE' => client.delete(
          request.uri,
          headers: request.headers,
          body: request.body,
        ),
      _ => client.get(request.uri, headers: request.headers),
    };
    return future.timeout(timeout);
  }

  static _PlaceSearchRequest _buildRequest({
    required String keyword,
    required PlaceSearchTransport transport,
    Map<String, dynamic>? extraPayload,
    double? latitude,
    double? longitude,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    Map<String, dynamic>? payload = extraPayload != null
        ? Map<String, dynamic>.from(extraPayload)
        : <String, dynamic>{};

    // 위치 파라미터 추가
    if (latitude != null && longitude != null) {
      payload['latitude'] = latitude;
      payload['longitude'] = longitude;
    }

    if (transport == PlaceSearchTransport.query) {
      final query = <String, String>{
        'keyword': keyword,
        ...payload.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      };
      final uri = _endpoint.replace(
        queryParameters: query,
      );
      return _PlaceSearchRequest(
        uri: uri,
        headers: headers,
        method: 'GET',
      );
    }

    payload['keyword'] = keyword;

    return _PlaceSearchRequest(
      uri: _endpoint,
      headers: headers,
      method: 'POST',
      body: json.encode(payload),
    );
  }
}

class _PlaceSearchRequest {
  final Uri uri;
  final Map<String, String> headers;
  final String method;
  final String? body;

  _PlaceSearchRequest({
    required this.uri,
    required this.headers,
    required this.method,
    this.body,
  });
}

enum PlaceSearchTransport { query, body }

class PlaceSearchException implements Exception {
  final String message;

  PlaceSearchException(this.message);

  @override
  String toString() => 'PlaceSearchException: $message';
}
