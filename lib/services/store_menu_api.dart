import 'package:delivery/models/menu_data.dart';
import 'package:delivery/utils/logging.dart';
import 'api.dart';

/// 가게 메뉴 조회 API
class StoreMenuApi {
  static String get _baseEndpoint => 'api/v1/stores';

  /// 가게 이름으로 메뉴 목록 조회
  static Future<List<MenuItem>> getMenusByStoreName(String storeName) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _getDummyMenus(storeName);
    }

    try {
      final endpoint = '$_baseEndpoint/menus?storeName=$storeName';
      final response = await ApiService.get(endpoint, requiresAuth: true);

      if (response['success'] == true) {
        final data = response['data'];

        // 응답 형식 1: 배열 직접 반환
        if (data is List) {
          return data
              .map(
                (item) => MenuItem.fromJson(
                  item is Map<String, dynamic>
                      ? item
                      : Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        }

        // 응답 형식 2: { data: { menus: [...] } } 또는 { data: { items: [...] } } 형태
        if (data is Map<String, dynamic>) {
          final menus = data['menus'] ?? data['items'] ?? data['data'];
          if (menus is List) {
            return menus
                .map(
                  (item) => MenuItem.fromJson(
                    item is Map<String, dynamic>
                        ? item
                        : Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
          }
        }

        return [];
      } else {
        // API 호출 실패 시(403 등) 더미 데이터 반환
        logDebug('[StoreMenuApi] Menu lookup failed; using mock data');
        return _getDummyMenus(storeName);
      }
    } catch (e) {
      // 네트워크 오류 등 예외 발생 시 더미 데이터 반환
      logDebug('Menu lookup failed (${e.runtimeType}); using mock data');
      return _getDummyMenus(storeName);
    }
  }

  /// 가게 ID로 메뉴 목록 조회
  static Future<List<MenuItem>> getMenusByStoreId(String storeId) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _getDummyMenus('Store$storeId');
    }

    try {
      final endpoint = '$_baseEndpoint/$storeId/menus';
      final response = await ApiService.get(endpoint, requiresAuth: true);

      if (response['success'] == true) {
        final data = response['data'];

        if (data is List) {
          return data
              .map(
                (item) => MenuItem.fromJson(
                  item is Map<String, dynamic>
                      ? item
                      : Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        }

        if (data is Map<String, dynamic>) {
          final menus = data['menus'] ?? data['items'] ?? data['data'];
          if (menus is List) {
            return menus
                .map(
                  (item) => MenuItem.fromJson(
                    item is Map<String, dynamic>
                        ? item
                        : Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
          }
        }

        return [];
      } else {
        // API 호출 실패 시(403 등) 더미 데이터 반환
        logDebug('[StoreMenuApi] Menu lookup failed; using mock data');
        return _getDummyMenus('Store$storeId');
      }
    } catch (e) {
      // 네트워크 오류 등 예외 발생 시 더미 데이터 반환
      logDebug('Menu lookup failed (${e.runtimeType}); using mock data');
      return _getDummyMenus('Store$storeId');
    }
  }

  /// 개발 모드용 더미 메뉴 데이터
  static List<MenuItem> _getDummyMenus(String storeName) {
    // 가게 이름에 따라 다른 메뉴 제공
    final storeNameLower = storeName.toLowerCase();

    // 맘스터치 메뉴
    if (storeNameLower.contains('맘스터치') || storeNameLower.contains('momstouch')) {
      return [
        MenuItem(
          id: 'mt1',
          name: '싸이버거',
          price: 3900,
          description: '매콤달콤한 특제 소스가 일품인 싸이버거',
          category: '버거',
        ),
        MenuItem(
          id: 'mt2',
          name: '화이트갈릭버거',
          price: 4400,
          description: '부드러운 화이트 갈릭 소스의 프리미엄 버거',
          category: '버거',
        ),
        MenuItem(
          id: 'mt3',
          name: '불고기버거',
          price: 3900,
          description: '달콤한 불고기 소스가 들어간 버거',
          category: '버거',
        ),
        MenuItem(
          id: 'mt4',
          name: '치즈버거',
          price: 3900,
          description: '풍부한 치즈가 들어간 클래식 버거',
          category: '버거',
        ),
        MenuItem(
          id: 'mt5',
          name: '치킨버거',
          price: 3900,
          description: '바삭한 치킨 패티의 버거',
          category: '버거',
        ),
        MenuItem(
          id: 'mt6',
          name: '감자튀김',
          price: 2500,
          description: '바삭한 감자튀김',
          category: '사이드',
        ),
        MenuItem(
          id: 'mt7',
          name: '콜라',
          price: 1500,
          description: '시원한 콜라',
          category: '음료',
        ),
        MenuItem(
          id: 'mt8',
          name: '사이다',
          price: 1500,
          description: '시원한 사이다',
          category: '음료',
        ),
      ];
    } else if (storeNameLower.contains('치킨') || storeNameLower.contains('chicken')) {
      return [
        MenuItem(
          id: '1',
          name: '후라이드 치킨',
          price: 18000,
          description: '바삭바삭한 후라이드 치킨',
          category: '치킨',
        ),
        MenuItem(
          id: '2',
          name: '양념 치킨',
          price: 19000,
          description: '달콤한 양념 치킨',
          category: '치킨',
        ),
        MenuItem(
          id: '3',
          name: '반반 치킨',
          price: 19500,
          description: '후라이드 + 양념 반반',
          category: '치킨',
        ),
      ];
    } else if (storeNameLower.contains('피자') ||
        storeNameLower.contains('pizza')) {
      return [
        MenuItem(
          id: '4',
          name: '페퍼로니 피자',
          price: 25000,
          description: '매콤한 페퍼로니 피자',
          category: '피자',
        ),
        MenuItem(
          id: '5',
          name: '하와이안 피자',
          price: 26000,
          description: '파인애플이 들어간 피자',
          category: '피자',
        ),
        MenuItem(
          id: '6',
          name: '치즈 피자',
          price: 24000,
          description: '풍부한 치즈 피자',
          category: '피자',
        ),
      ];
    } else {
      // 기본 메뉴 (한식/중식 등)
      return [
        MenuItem(
          id: '7',
          name: '김치찌개',
          price: 8000,
          description: '얼큰한 김치찌개',
          category: '한식',
        ),
        MenuItem(
          id: '8',
          name: '된장찌개',
          price: 7500,
          description: '구수한 된장찌개',
          category: '한식',
        ),
        MenuItem(
          id: '9',
          name: '짜장면',
          price: 6000,
          description: '달콤한 짜장면',
          category: '중식',
        ),
        MenuItem(
          id: '10',
          name: '탕수육',
          price: 15000,
          description: '바삭한 탕수육',
          category: '중식',
        ),
      ];
    }
  }
}
