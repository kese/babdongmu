import 'package:delivery/utils/logging.dart';
import 'dummy_delivery_posts.dart';
import 'dummy_friend_posts.dart';

class DummyDataCache {

  static final List<Map<String, dynamic>> tempChatRoomsList = [];
  static final Map<String, bool> tempSharedCartActiveState = {};
  static final Map<String, Map<String, dynamic>> tempReceipts = {};
  static final Map<String, List<Map<String, dynamic>>> tempChatMessages = {};
  static final Map<String, String> tempChatRoomStatus = {};
  static final Map<String, List<Map<String, dynamic>>> tempSharedCartItems = {};
  static final Map<String, Map<String, int>> tempDeliveryFeeInfo = {};
  static final Map<String, List<Map<String, dynamic>>> tempSettlementRequests =
      {};
}

class DummyPostStore {
  DummyPostStore._();

  static final List<Map<String, dynamic>> tempDeliveryPosts =
      _initDeliveryPosts();
  static final List<Map<String, dynamic>> tempFriendPosts =
      _initFriendPosts();
  static int postIdCounter = 100;

  static List<Map<String, dynamic>> _initDeliveryPosts() {
    final now = DateTime.now();
    // 더미 데이터 파일에서 가져온 게시글 + 테스트용 게시글
    return [
      ...dummyDeliveryPosts, // 새로 추가한 더미 데이터
      // 기존 테스트용 게시글들 (매칭 테스트용)
      {
        'id': 'test_accept_post',
        'userName': '테스트 사용자 A',
        'date': '${now.month}월 ${now.day}일',
        'title': '교촌치킨 배달 같이해요~ (자동 수락)',
        'store_name': '교촌치킨',
        'store_latitude': 37.505,
        'store_longitude': 127.049,
        'delivery_place': '공용 수령 장소',
        'delivery_latitude': 37.505,
        'delivery_longitude': 127.049,
        'target_price': 25000,
        'current_people': 2,
        'max_people': 4,
        'delivery_fee': 4000,
        'fee_per_person': 1000,
        'is_recruiting': true,
        'deadline': now.add(const Duration(hours: 2)).toIso8601String(),
        'participants': ['테스트 사용자 A', '테스트 참여자 A'],
      },
      {
        'id': 'test_reject_post',
        'userName': '테스트 사용자 B',
        'date': '${now.month}월 ${now.day}일',
        'title': '교촌치킨 주문하실분! (자동 거절)',
        'store_name': '교촌치킨',
        'store_latitude': 37.505,
        'store_longitude': 127.050,
        'delivery_place': '공용 수령 장소',
        'delivery_latitude': 37.505,
        'delivery_longitude': 127.049,
        'target_price': 25000,
        'current_people': 1,
        'max_people': 3,
        'delivery_fee': 4000,
        'fee_per_person': 1333,
        'is_recruiting': true,
        'deadline': now.add(const Duration(hours: 2)).toIso8601String(),
        'participants': ['테스트 사용자 B'],
      },
      {
        'id': 'test_pending_request_post',
        'userName': '테스트 응답자',
        'date': '${now.month}월 ${now.day}일',
        'title': '교촌치킨 같이 드실 분 구해요',
        'store_name': '교촌치킨',
        'store_latitude': 37.505,
        'store_longitude': 127.049,
        'delivery_place': '공용 수령 장소',
        'delivery_latitude': 37.505,
        'delivery_longitude': 127.049,
        'target_price': 25000,
        'current_people': 1,
        'max_people': 2,
        'delivery_fee': 4000,
        'fee_per_person': 2000,
        'is_recruiting': true,
        'deadline': now.add(const Duration(hours: 4)).toIso8601String(),
        'participants': ['테스트 응답자'],
      },
    ];
  }

  static List<Map<String, dynamic>> _initFriendPosts() {
    // 더미 데이터 파일에서 가져온 친구 찾기 게시글
    return [...dummyFriendPosts];
  }

  static void addTempDeliveryPost(Map<String, dynamic> post) {
    tempDeliveryPosts.removeWhere((p) => p['id'] == post['id']);
    tempDeliveryPosts.insert(0, post);
  }
}

class DummyAuthStore {
  DummyAuthStore._();

  static final List<Map<String, String>> tempUsers = [];

  static void printUsers() {
    logDebug('Mock user count: ${tempUsers.length}');
  }
}

class DummyJointOrderStore {
  DummyJointOrderStore._();

  static final List<Map<String, dynamic>> tempJointOrderRequests =
      _initJointOrderRequests();
  static int requestIdCounter = 10;
  static bool pendingRequestsForbidden = false;

  static List<Map<String, dynamic>> _initJointOrderRequests() {
    return [
      {
        'id': 'pending_request_1',
        'requester_id': 'requester_user_id',
        'requester_name': '테스트 사용자 A',
        'requester_post_id': 'test_accept_post',
        'target_post_ids': ['test_pending_request_post'],
        'request_time': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
        'status': 'pending',
        'responses': <Map<String, dynamic>>[],
      },
    ];
  }

  static void resetPendingRequestsCache() {
    pendingRequestsForbidden = false;
  }
}

class DummyUserStore {
  DummyUserStore._();

  static String? currentUserEmail;

  static final Map<String, dynamic> masterUserProfile = {
    'name': '개발자',
    'email': 'demo-owner@example.invalid',
    'phone': '000-0000-0000',
    'nickname': '개발자',
    'address': '예시 지역',
    'account': '예시 계좌',
    'profile_image': null,
  };

  static final Map<String, dynamic> responderUserProfile = {
    'name': '요청 응답자',
    'email': 'demo-responder@example.invalid',
    'phone': '000-0000-0000',
    'nickname': '응답자',
    'address': '예시 지역',
    'account': '예시 계좌',
    'profile_image': null,
  };

  static int masterUserPoints = 15000;
  static final Map<String, int> userPointsMap = {};

  static final int totalOrders = 3;
  static final int totalDeliveryFeeSaved = 6000;
  static final int totalDeliveryFeePaid = 3000;
  static final int originalDeliveryFee = 9000;

  static void setCurrentUser(String email) {
    currentUserEmail = email;
  }

  static Map<String, dynamic>? getCurrentUserData(
      List<Map<String, String>> tempUsers) {
    if (currentUserEmail == null) return null;

    if (currentUserEmail == 'demo-owner@example.invalid') {
      return masterUserProfile;
    }

    if (currentUserEmail == 'demo-responder@example.invalid') {
      return responderUserProfile;
    }

    for (var user in tempUsers) {
      if (user['email'] == currentUserEmail) {
        return user;
      }
    }

    return null;
  }

  static void printTempUserData() {
    logDebug('=== 개발모드 사용자 데이터 ===');
    logDebug('Mock profile state available');
    logDebug('=======================');
  }
}
