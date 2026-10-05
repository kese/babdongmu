// 게시글 관련 API 관리
import 'package:delivery/utils/logging.dart';
import 'package:delivery/dummy_data/dummy.dart';
import 'api.dart';

class PostApi {
  /// 게시글 목록 가져오기
  static Future<Map<String, dynamic>> getPosts({
    String? type,
    double? lat,
    double? lng,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));
      // 개발 모드에서는 위치 필터링을 흉내 내지 않음
      if (type == 'delivery') {
        return {'success': true, 'data': DummyPostStore.tempDeliveryPosts};
      } else if (type == 'friend') {
        return {'success': true, 'data': DummyPostStore.tempFriendPosts};
      }
      return {
        'success': true,
        'data': [
          ...DummyPostStore.tempDeliveryPosts,
          ...DummyPostStore.tempFriendPosts,
        ],
      };
    }

    final queryParams = <String, String>{};
    if (type != null) queryParams['type'] = type;
    if (lat != null) queryParams['lat'] = lat.toString();
    if (lng != null) queryParams['lng'] = lng.toString();

    final queryString = Uri(queryParameters: queryParams).query;
    final url = 'api/v1/posts${queryString.isNotEmpty ? '?$queryString' : ''}';

    final result = await ApiService.get(url, requiresAuth: true);

    if (result['success'] != true) {
      return result;
    }

    final normalized = _normalizePosts(result['data']);
    final filtered = type == null
        ? normalized
        : normalized
              .where((post) => _matchesType(post, type))
              .toList(growable: false);

    return {'success': true, 'data': filtered};
  }

  /// 특정 게시글 가져오기
  static Future<Map<String, dynamic>> getPost(String id) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      // 배달 게시글에서 찾기
      final deliveryPost = DummyPostStore.tempDeliveryPosts
          .firstWhere((post) => post['id'] == id, orElse: () => {});

      if (deliveryPost.isNotEmpty) {
        return {
          'success': true,
          'data': deliveryPost,
        };
      }

      // 친구 찾기 게시글에서 찾기
      final friendPost = DummyPostStore.tempFriendPosts
          .firstWhere((post) => post['id'] == id, orElse: () => {});

      if (friendPost.isNotEmpty) {
        return {
          'success': true,
          'data': friendPost,
        };
      }

      return {
        'success': false,
        'message': '게시글을 찾을 수 없습니다',
      };
    }

    return await ApiService.get('api/v1/posts/$id', requiresAuth: true);
  }

  /// 게시글 작성
  static Future<Map<String, dynamic>> createPost(
    Map<String, dynamic> postData,
  ) async {
    return await ApiService.post('api/v1/posts', postData, requiresAuth: true);
  }

  /// 게시글 수정
  static Future<Map<String, dynamic>> updatePost(
    String id,
    Map<String, dynamic> postData,
  ) async {
    return await ApiService.put(
      'api/v1/posts/$id',
      postData,
      requiresAuth: true,
    );
  }

  /// 게시글 삭제
  static Future<Map<String, dynamic>> deletePost(String id) async {
    return await ApiService.delete('api/v1/posts/$id', requiresAuth: true);
  }

  /// '함께 배달' 게시글 목록 가져오기
  static Future<Map<String, dynamic>> getDeliveryPosts({
    double? lat,
    double? lng,
  }) async {
    return await getPosts(type: 'delivery', lat: lat, lng: lng);
  }

  /// '같이 먹을 친구 구하기' 게시글 목록 가져오기
  static Future<Map<String, dynamic>> getFriendPosts({
    double? lat,
    double? lng,
  }) async {
    return await getPosts(type: 'friend', lat: lat, lng: lng);
  }

  static List<Map<String, dynamic>> _normalizePosts(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((post) => Map<String, dynamic>.from(post))
          .toList(growable: false);
    }

    if (raw is Map) {
      for (final key in ['data', 'content', 'items']) {
        final value = raw[key];
        if (value is List) {
          return _normalizePosts(value);
        }
      }
    }

    return const [];
  }

  static bool _matchesType(Map<String, dynamic> post, String type) {
    final rawType = post['postType'] ?? post['type'] ?? post['post_type'];
    if (rawType is! String) return false;

    final t = rawType.toLowerCase();
    // Normalize common server values to client 'type' values
    // 서버가 'DELIVERY' 또는 'delivery' 를 보낼 수 있고,
    // 친구 타입은 'meet'로 보내는 경우가 있음(서버 코드에서 'meet' 사용).
    if (t == 'delivery' ||
        t == 'del' ||
        t == 'delivery_post' ||
        t == 'deliver') {
      return type.toLowerCase() == 'delivery';
    }

    if (t == 'meet' || t == 'meetup' || t == 'friend' || t == 'friend_post') {
      return type.toLowerCase() == 'friend';
    }

    // fallback: exact match
    return t == type.toLowerCase();
  }

  /// '함께 배달' 게시글 생성
  static Future<Map<String, dynamic>> createDeliveryPost({
    required String title,
    required String? details,
    required String storeName,
    double? deliveryLatitude,
    double? deliveryLongitude,
    required String orderLink,
    required int targetPrice,
    required int deliveryFee,
    required int maxPeople,
    required DateTime deadline,
    String? locationName,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    final placeName = locationName?.trim();
    final publicPlace = placeName != null && placeName.isNotEmpty
        ? placeName
        : '선택한 주변 위치';
    final publicLatitude = _roundPublicCoordinate(
      locationLatitude ?? deliveryLatitude,
    );
    final publicLongitude = _roundPublicCoordinate(
      locationLongitude ?? deliveryLongitude,
    );

    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));
      final now = DateTime.now();
      final userNickname = await ApiService.getUserNickname() ?? '익명';
      final newPost = {
        'id': (DummyPostStore.postIdCounter++).toString(),
        'userName': userNickname,
        'date': '${now.month}월 ${now.day}일',
        'title': title,
        'store_name': storeName,
        'delivery_place': publicPlace,
        'delivery_address': publicPlace,
        if (publicLatitude != null) 'delivery_latitude': publicLatitude,
        if (publicLongitude != null) 'delivery_longitude': publicLongitude,
        'target_price': targetPrice,
        'current_people': 1,
        'max_people': maxPeople,
        'delivery_fee': deliveryFee,
        'fee_per_person': (deliveryFee / maxPeople).ceil(),
        'is_recruiting': true,
        'deadline': deadline.toIso8601String(),
        'details': details,
      };

      DummyPostStore.tempDeliveryPosts.insert(0, newPost);

      logDebug('Mock delivery post created');
      return {
        'success': true,
        'message': '게시글 작성 완료',
        'data': {'id': newPost['id']},
      };
    }

    final postData = {
      'postType': 'DELIVERY',
      'title': title,
      'content': details,
      'meetingTime': deadline.toIso8601String(),
      'meetingPlace': publicPlace,
      'locationLatitude': publicLatitude,
      'locationLongitude': publicLongitude,
      if (locationName != null)
        'locationName': locationName, // POI 순수명만 (없으면 null)
      'locationAddress': publicPlace,
      'maxParticipants': maxPeople,
      'deliveryDetail': {
        'restaurantName': storeName,
        'deliveryFee': deliveryFee,
        'targetAmount': targetPrice,
        'deliveryAddress': publicPlace,
        if (publicLatitude != null) 'deliveryLatitude': publicLatitude,
        if (publicLongitude != null) 'deliveryLongitude': publicLongitude,
        'orderLink': orderLink,
      },
    };

    return await createPost(postData);
  }

  /// '같이 먹을 친구 구하기' 게시글 생성
  static Future<Map<String, dynamic>> createFriendPost({
    required String title,
    required String? details,
    required String meetingPlace,
    double? meetingLatitude,
    double? meetingLongitude,
    required int maxPeople,
    required DateTime deadline,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));
      final now = DateTime.now();
      final userNickname = await ApiService.getUserNickname() ?? '익명';
      final newPost = {
        'id': (DummyPostStore.postIdCounter++).toString(),
        'userName': userNickname,
        'date': '${now.month}월 ${now.day}일', // 'MM월 dd일' 형식
        'title': title,
        'store_name': meetingPlace, // UI상 '음식점'으로 입력받은 값
        'meeting_place': meetingPlace,
        if (meetingLatitude != null) 'meeting_latitude': meetingLatitude,
        if (meetingLongitude != null) 'meeting_longitude': meetingLongitude,
        'current_people': 1,
        'max_people': maxPeople,
        'is_recruiting': true,
        'deadline': deadline.toIso8601String(),
        'details': details,
      };

      DummyPostStore.tempFriendPosts.insert(0, newPost);

      logDebug('Mock meetup post created');
      return {
        'success': true,
        'message': '게시글 작성 완료',
        'data': {'id': newPost['id']},
      };
    }

    final postData = {
      'postType': 'meet',
      'title': title,
      'content': details,
      'meetingTime': deadline.toIso8601String(),
      'maxParticipants': maxPeople,
      'meetDetail': {
        'restaurantName': meetingPlace, // UI상 '음식점'으로 입력받은 값 (음식점 = 만날 장소로 통합)
        'meetingPlace': meetingPlace,
        if (meetingLatitude != null) 'meetingLatitude': meetingLatitude,
        if (meetingLongitude != null) 'meetingLongitude': meetingLongitude,
        'meetingTime': deadline.toIso8601String(),
        'additionalNotes': details,
      },
    };
    return await createPost(postData);
  }

  /// 배달 게시글 참여
  static Future<Map<String, dynamic>> joinDeliveryPost(String postId) async {
    if (!_isValidPostId(postId)) {
      return {'success': false, 'message': '유효하지 않은 게시글 ID입니다'};
    }

    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      final userNickname = await ApiService.getUserNickname() ?? '익명';

      // 해당 게시글 찾기
      final postIndex = DummyPostStore.tempDeliveryPosts.indexWhere(
        (post) => post['id'] == postId,
      );

      if (postIndex == -1) {
        return {'success': false, 'message': '게시글을 찾을 수 없습니다'};
      }

      final post = DummyPostStore.tempDeliveryPosts[postIndex];

      // 모집 완료 확인
      if (post['is_recruiting'] == false) {
        return {'success': false, 'message': '이미 모집이 완료된 게시글입니다'};
      }

      // 중복 참여 확인 (임시로 참여자 목록이 없으므로 participants 필드 추가)
      final List<String> participants = List<String>.from(
        post['participants'] ?? [post['userName']],
      );

      if (participants.contains(userNickname)) {
        return {'success': false, 'message': '이미 참여한 게시글입니다'};
      }

      // 참여자 추가
      participants.add(userNickname);
      final newCurrentPeople = post['current_people'] + 1;
      final maxPeople = post['max_people'];

      // 인원수 업데이트
      DummyPostStore.tempDeliveryPosts[postIndex]['current_people'] =
          newCurrentPeople;
      DummyPostStore.tempDeliveryPosts[postIndex]['participants'] =
          participants;

      // 채팅방 ID 가져오기 또는 생성
      String chatRoomId = post['chat_room_id'] ?? 'room_${postId}_${DateTime.now().millisecondsSinceEpoch}';

      // 채팅방 ID가 없었다면 저장
      if (post['chat_room_id'] == null) {
        DummyPostStore.tempDeliveryPosts[postIndex]['chat_room_id'] = chatRoomId;
      }

      // 최대 인원 도달 시 모집 완료 처리
      if (newCurrentPeople >= maxPeople) {
        DummyPostStore.tempDeliveryPosts[postIndex]['is_recruiting'] = false;
      }


      return {
        'success': true,
        'message': '참여가 완료되었습니다',
        'data': {
          'current_people': newCurrentPeople,
          'is_full': newCurrentPeople >= maxPeople,
          'chat_room_id': chatRoomId,
        },
      };
    }

    // 실제 API 호출 ('' 부분 실제 엔드포인트와 다를 경우 수정 필요)
    return await ApiService.post(
      'api/v1/posts/$postId/join',
      null,
      requiresAuth: true,
    );
  }

  /// 친구 찾기 게시글 참여하기
  static Future<Map<String, dynamic>> joinFriendPost(String postId) async {
    if (!_isValidPostId(postId)) {
      return {'success': false, 'message': '유효하지 않은 게시글 ID입니다'};
    }

    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      final userNickname = await ApiService.getUserNickname() ?? '익명';

      // 해당 게시글 찾기
      final postIndex = DummyPostStore.tempFriendPosts.indexWhere(
        (post) => post['id'] == postId,
      );

      if (postIndex == -1) {
        return {'success': false, 'message': '게시글을 찾을 수 없습니다'};
      }

      final post = DummyPostStore.tempFriendPosts[postIndex];

      // 모집 완료 확인
      if (post['is_recruiting'] == false) {
        return {'success': false, 'message': '이미 모집이 완료된 게시글입니다'};
      }

      // 중복 참여 확인 (임시로 참여자 목록이 없으므로 participants 필드 추가)
      final List<String> participants = List<String>.from(
        post['participants'] ?? [post['userName']],
      );

      if (participants.contains(userNickname)) {
        return {'success': false, 'message': '이미 참여한 게시글입니다'};
      }

      // 참여자 추가
      participants.add(userNickname);
      final newCurrentPeople = post['current_people'] + 1;
      final maxPeople = post['max_people'];

      // 인원수 업데이트
      DummyPostStore.tempFriendPosts[postIndex]['current_people'] =
          newCurrentPeople;
      DummyPostStore.tempFriendPosts[postIndex]['participants'] = participants;

      // 채팅방 ID 가져오기 또는 생성
      String chatRoomId = post['chat_room_id'] ?? 'room_${postId}_${DateTime.now().millisecondsSinceEpoch}';

      // 채팅방 ID가 없었다면 저장
      if (post['chat_room_id'] == null) {
        DummyPostStore.tempFriendPosts[postIndex]['chat_room_id'] = chatRoomId;
      }

      // 최대 인원 도달 시 모집 완료 처리
      if (newCurrentPeople >= maxPeople) {
        DummyPostStore.tempFriendPosts[postIndex]['is_recruiting'] = false;
      }


      return {
        'success': true,
        'message': '참여가 완료되었습니다',
        'data': {
          'current_people': newCurrentPeople,
          'is_full': newCurrentPeople >= maxPeople,
          'chat_room_id': chatRoomId,
        },
      };
    }

    // 실제 API 호출 ('' 부분 실제 엔드포인트와 다를 경우 수정 필요)
    return await ApiService.post(
      'api/v1/posts/$postId/join',
      null,
      requiresAuth: true,
    );
  }

  /// 배달 게시글 참여 취소
  static Future<Map<String, dynamic>> leaveDeliveryPost(String postId) async {
    if (!_isValidPostId(postId)) {
      return {'success': false, 'message': '유효하지 않은 게시글 ID입니다'};
    }

    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      final userNickname = await ApiService.getUserNickname() ?? '익명';

      // 해당 게시글 찾기
      final postIndex = DummyPostStore.tempDeliveryPosts.indexWhere(
        (post) => post['id'] == postId,
      );

      if (postIndex == -1) {
        return {'success': false, 'message': '게시글을 찾을 수 없습니다'};
      }

      final post = DummyPostStore.tempDeliveryPosts[postIndex];

      // 모집 완료 확인 - 모집 완료된 게시글은 나갈 수 없음
      if (post['is_recruiting'] == false) {
        return {'success': false, 'message': '모집이 완료된 게시글은 나갈 수 없습니다'};
      }

      // 참여자 목록에서 제거
      final List<String> participants = List<String>.from(
        post['participants'] ?? [post['userName']],
      );

      if (!participants.contains(userNickname)) {
        return {'success': false, 'message': '참여하지 않은 게시글입니다'};
      }

      participants.remove(userNickname);
      final newCurrentPeople = post['current_people'] - 1;

      // 인원수 업데이트
      DummyPostStore.tempDeliveryPosts[postIndex]['current_people'] =
          newCurrentPeople;
      DummyPostStore.tempDeliveryPosts[postIndex]['participants'] =
          participants;


      return {
        'success': true,
        'message': '게시글 참여를 취소했습니다',
        'data': {'current_people': newCurrentPeople},
      };
    }

    // 실제 API 호출
    return await ApiService.post(
      'api/v1/posts/$postId/leave',
      null,
      requiresAuth: true,
    );
  }

  /// 모집 상태를 '모집완료'로 변경
  static Future<Map<String, dynamic>> closeRecruitment(String postId) async {
    if (!_isValidPostId(postId)) {
      return {'success': false, 'message': '유효하지 않은 게시글 ID입니다'};
    }

    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 400));
      var updated = false;

      void markClosed(List<Map<String, dynamic>> posts) {
        final index = posts.indexWhere((post) => post['id'] == postId);
        if (index == -1) {
          return;
        }
        posts[index]['is_recruiting'] = false;
        updated = true;
      }

      markClosed(DummyPostStore.tempDeliveryPosts);
      markClosed(DummyPostStore.tempFriendPosts);

      if (!updated) {
        return {'success': false, 'message': '게시글을 찾을 수 없습니다'};
      }

      return {'success': true, 'message': '모집이 마감되었습니다'};
    }

    try {
      final response = await ApiService.post(
        'api/v1/posts/$postId/close',
        null,
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      logDebug('Post status update failed (${e.runtimeType})');

      // 500 에러인 경우 서버 문제임을 명확히 표시
      if (e.toString().contains('500')) {
        return {
          'success': false,
          'message': '서버 오류로 모집 상태 변경에 실패했습니다. 잠시 후 다시 시도해주세요.',
          'statusCode': 500,
        };
      }

      return {
        'success': false,
          'message': '모집 상태 변경에 실패했습니다.',
        'statusCode': e.toString().contains('403') ? 403 : 400,
      };
    }
  }

  static double? _roundPublicCoordinate(double? value) {
    if (value == null) return null;
    return (value * 1000).roundToDouble() / 1000;
  }

  static bool _isValidPostId(String postId) {
    final trimmed = postId.trim();
    return RegExp(r'^\d+$').hasMatch(trimmed);
  }

  /// (개발용) 임시 배달 게시글 추가
  static void addTempDeliveryPost(Map<String, dynamic> post) {
    DummyPostStore.addTempDeliveryPost(post);
  }
}
