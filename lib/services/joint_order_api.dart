/// 합동 주문 매칭 관련 API 관리
library;

import 'package:delivery/utils/logging.dart';
import 'package:delivery/dummy_data/dummy.dart';
import 'api.dart';

class JointOrderApi {
  /// 폴백 폴링 관련 캐시를 초기화 (로그인/로그아웃 시 호출)
  static void resetPendingRequestsCache() {
    DummyJointOrderStore.resetPendingRequestsCache();
  }

  /// 사용자의 게시글 정보 가져오기 (매칭 가능 여부 확인용)
  static Future<Map<String, dynamic>> getUserPost() async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      final userNickname = await ApiService.getUserNickname() ?? '익명';

      // PostApi의 임시 데이터에서 현재 사용자가 작성한 게시글 찾기
      final deliveryPosts = await _getDeliveryPosts();

      // 현재 사용자가 작성한 게시글 중 모집 중인 것 찾기
      final userPost = deliveryPosts.firstWhere(
        (post) =>
            post['userName'] == userNickname && post['is_recruiting'] == true,
        orElse: () => <String, dynamic>{},
      );

      if (userPost.isEmpty) {
        // 테스트를 위해 마스터 계정이면 자동으로 게시글 생성
        if (userNickname == '개발자') {
          final now = DateTime.now();
          final testPost = {
            'id': 'master_post_auto',
            'userName': '개발자',
            'date': '${now.month}월 ${now.day}일',
            'title': '교촌치킨 같이 시켜요!',
            'store_name': '교촌치킨',
            'delivery_place': '선릉역 2번 출구',
            'delivery_fee': 4000,
            'target_price': 25000,
            'current_people': 1,
            'max_people': 4,
            'fee_per_person': 1000,
            'is_recruiting': true,
            'deadline': now.add(const Duration(hours: 3)).toIso8601String(),
            'participants': ['개발자'],
          };

          logDebug('[JointOrderApi] 마스터 계정 테스트용 게시글 자동 생성');

          // PostApi의 임시 데이터 목록에 이 게시글을 추가해야 다른 API에서 조회 가능
          PostApi.addTempDeliveryPost(testPost);

          return {'success': true, 'data': testPost};
        }

        return {
          'success': false,
          'message': '매칭 가능한 게시글이 없습니다. 모집 중인 게시글을 먼저 생성해주세요.',
        };
      }

      // 모집 인원이 다 찬 경우
      if (userPost['current_people'] >= userPost['max_people']) {
        return {'success': false, 'message': '이미 모집 인원이 다 찼습니다.'};
      }

      return {'success': true, 'data': userPost};
    }

    // API 연동
    final response = await ApiService.get(
      'api/v1/joint-orders/my-post',
      requiresAuth: true,
    );

    if (response['success'] == true && response['data'] != null) {
      // "주소 미입력" 문자열을 null로 정규화
      final data = Map<String, dynamic>.from(response['data']);
      if (data['deliveryPlace'] == '주소 미입력') {
        data['deliveryPlace'] = null;
      }
      if (data['deliveryDetail'] != null &&
          data['deliveryDetail']['deliveryAddress'] == '주소 미입력') {
        data['deliveryDetail']['deliveryAddress'] = null;
      }
      response['data'] = data;

      logDebug('[JointOrderApi] 주소 데이터 정규화 완료');
    }

    return response;
  }

  /// 매칭 가능한 게시글 목록 가져오기
  static Future<Map<String, dynamic>> getMatchablePosts({
    required String storeName,
    required String deliveryPlace,
    required int deliveryFee,
    required String locationName,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 800));

      final userNickname = await ApiService.getUserNickname() ?? '익명';
      final deliveryPosts = await _getDeliveryPosts();

      // 동일한 음식점과 배달 장소를 가진 게시글 필터링 (배달비는 달라도 허용)
      final matchablePosts = deliveryPosts.where((post) {
        return post['store_name'] == storeName &&
            post['delivery_place'] == deliveryPlace &&
            post['userName'] != userNickname && // 본인 게시글 제외
            post['is_recruiting'] == true && // 모집 중인 것만
            post['current_people'] < post['max_people']; // 인원이 다 차지 않은 것만
      }).toList();


      return {'success': true, 'data': matchablePosts};
    }

    // API 연동
    return await ApiService.get(
      'api/v1/joint-orders/matchable?storeName=${Uri.encodeComponent(storeName)}&deliveryPlace=${Uri.encodeComponent(deliveryPlace)}&deliveryFee=$deliveryFee&locationName=${Uri.encodeComponent(locationName)}',
      requiresAuth: true,
    );
  }

  /// 합동 주문 요청 보내기
  static Future<Map<String, dynamic>> sendJointOrderRequest({
    required String requesterPostId,
    required List<String> targetPostIds,
  }) async {
    if (ApiService.isDevelopment) {
      final (userId, userNickname) = await _getCurrentUserInfo();

      final requestId = (DummyJointOrderStore.requestIdCounter++).toString();
      final now = DateTime.now();
      final requestData = {
        'id': requestId,
        'requester_id': userId,
        'requester_name': userNickname,
        'requester_post_id': requesterPostId,
        'target_post_ids': targetPostIds,
        'request_time': now.toIso8601String(),
        'created_at': now.millisecondsSinceEpoch, // 타임아웃 체크용
        'timeout_seconds': 60, // 60초 타임아웃
        'status': 'pending',
        'responses': <Map<String, dynamic>>[],
      };

      DummyJointOrderStore.tempJointOrderRequests.add(requestData);


      // 자동 응답 로직 (테스트용)
      _autoRespondToTestPosts(requestId, targetPostIds);

      // 타임아웃 타이머 시작 (60초)
      _startRequestTimeout(requestId, 60);

      return {
        'success': true,
        'data': {'request_id': requestId, 'message': '합동 주문 요청이 전송되었습니다.'},
      };
    }

    // API 연동
    final requestData = {
      'requester_post_id': int.parse(requesterPostId),
      'target_post_ids': targetPostIds.map((id) => int.parse(id)).toList(),
    };

    final response = await ApiService.post(
      'api/v1/joint-orders/request',
      requestData,
      requiresAuth: true,
    );

    // 서버 응답(requestId/camelCase)을 클라이언트 공통 포맷(request_id/snake_case)으로 정규화
    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data']);
      final rawRequestId = data['requestId'] ?? data['request_id'];
      if (rawRequestId != null) {
        data['request_id'] = rawRequestId.toString();
        response['data'] = data;
      }
    }

    return response;
  }

  /// 합동 주문 요청 상태 확인
  static Future<Map<String, dynamic>> checkRequestStatus(
    String requestId,
  ) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      if (requestId.isEmpty) {
        return {'success': false, 'message': '요청 ID가 유효하지 않습니다.'};
      }

      final request = DummyJointOrderStore.tempJointOrderRequests.firstWhere(
        (r) => r['id'] == requestId,
        orElse: () => <String, dynamic>{},
      );

      if (request.isEmpty) {
        return {'success': false, 'message': '요청을 찾을 수 없습니다.'};
      }

      // 타임아웃 체크 - 요청이 만료되었는지 확인
      final requestTime = DateTime.tryParse(request['request_time'] ?? '');
      final timeoutSeconds = request['timeout_seconds'] ?? 300; // 기본 5분

      if (requestTime != null) {
        final elapsed = DateTime.now().difference(requestTime);
        if (elapsed.inSeconds > timeoutSeconds) {
          return {'success': false, 'message': '요청이 만료되었습니다.'};
        }
      }

      return {'success': true, 'data': request};
    }

    // API 연동
    if (requestId.isEmpty) {
      return {'success': false, 'message': '요청 ID가 유효하지 않습니다.'};
    }

    final result = await ApiService.get(
      'api/v1/joint-orders/request/$requestId',
      requiresAuth: true,
    );

    // 응답 데이터 null 체크
    if (result['data'] == null) {
      return {'success': false, 'message': '요청 상태를 확인할 수 없습니다.'};
    }

    final rawData = Map<String, dynamic>.from(result['data']);

    // 서버 응답(camelCase)을 클라이언트 공통 포맷(snake_case)으로 정규화
    final normalized = Map<String, dynamic>.from(rawData);

    // requestId -> request_id
    final rawRequestId = rawData['requestId'] ?? rawData['request_id'];
    if (rawRequestId != null) {
      normalized['request_id'] = rawRequestId.toString();
    }

    // requesterPostId -> requester_post_id
    final requesterPostId =
        rawData['requesterPostId'] ?? rawData['requester_post_id'];
    if (requesterPostId != null) {
      normalized['requester_post_id'] = requesterPostId.toString();
    }

    // targetPostIds -> target_post_ids
    final targetPostIds =
        rawData['target_post_ids'] ?? rawData['targetPostIds'];
    if (targetPostIds is List) {
      normalized['target_post_ids'] = targetPostIds
          .map((id) => id.toString())
          .toList();
    }

    // responses[].postId/responderName/responseTime -> snake_case로 변환
    final responses = rawData['responses'];
    if (responses is List) {
      normalized['responses'] = responses.map((item) {
        final m = Map<String, dynamic>.from(
          item is Map ? item : <String, dynamic>{},
        );
        m['post_id'] = m['post_id'] ?? m['postId'];
        m['responder_name'] = m['responder_name'] ?? m['responderName'];
        m['response_time'] = m['response_time'] ?? m['responseTime'];
        return m;
      }).toList();
    }

    // chatRoomId -> chat_room_id (서버에서 상태 응답에 채팅방 ID를 포함하는 경우 대비)
    final rawChatRoomId = rawData['chatRoomId'] ?? rawData['chat_room_id'];
    if (rawChatRoomId != null) {
      normalized['chat_room_id'] = rawChatRoomId.toString();
    }

    result['data'] = normalized;

    final requestStatus = normalized;
    if (requestStatus['status'] != null &&
        requestStatus['status'] == 'timeout') {
      return {'success': false, 'message': '요청이 만료되었습니다.'};
    }

    return result;
  }

  /// 합동 주문 요청에 응답하기
  static Future<Map<String, dynamic>> respondToRequest({
    required String requestId,
    required String postId,
    required bool accepted,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      final requestIndex = DummyJointOrderStore.tempJointOrderRequests
          .indexWhere((r) => r['id'] == requestId);

      if (requestIndex == -1) {
        return {'success': false, 'message': '요청을 찾을 수 없습니다.'};
      }

      final (userId, userNickname) = await _getCurrentUserInfo();

      final response = {
        'request_id': requestId,
        'post_id': postId,
        'responder_id': userId,
        'responder_name': userNickname,
        'accepted': accepted,
        'response_time': DateTime.now().toIso8601String(),
      };

      final responses = List<Map<String, dynamic>>.from(
        DummyJointOrderStore
                .tempJointOrderRequests[requestIndex]['responses'] ??
            [],
      );
      responses.add(response);
      DummyJointOrderStore.tempJointOrderRequests[requestIndex]['responses'] =
          responses;

      // 모든 대상 게시글에서 응답이 왔는지 확인
      final targetPostIds = List<String>.from(
        DummyJointOrderStore
            .tempJointOrderRequests[requestIndex]['target_post_ids'],
      );

      if (responses.length >= targetPostIds.length) {
        // 모두 수락했는지 확인
        final allAccepted = responses.every((r) => r['accepted'] == true);

        if (allAccepted) {
          DummyJointOrderStore.tempJointOrderRequests[requestIndex]['status'] =
              'accepted';
          logDebug('[JointOrderApi] 모든 게시글 작성자가 수락 - 매칭 성공!');

          // Mock responder scenario: acceptance creates a room and activates the cart
          if (postId == 'test_pending_request_post') {
            Future.delayed(const Duration(milliseconds: 500), () {
              _createTestChatRoomForResponder(requestId);
            });
          }
        } else {
          DummyJointOrderStore.tempJointOrderRequests[requestIndex]['status'] =
              'rejected';
          logDebug('[JointOrderApi] 일부 거절 - 매칭 실패');
        }
      }

      logDebug(
        '[JointOrderApi] 합동 주문 응답: ${accepted ? "수락" : "거절"} (${responses.length}/${targetPostIds.length})',
      );

      return {
        'success': true,
        'data': {
          'accepted': accepted,
          'message': accepted ? '합동 주문 요청을 수락했습니다.' : '합동 주문 요청을 거절했습니다.',
        },
      };
    }

    // API 연동
    final responseData = {'post_id': int.parse(postId), 'accepted': accepted};

    return await ApiService.post(
      'api/v1/joint-orders/request/$requestId/respond',
      responseData,
      requiresAuth: true,
    );
  }

  /// 사용자에게 온 합동 주문 요청 목록 가져오기
  static Future<Map<String, dynamic>> getPendingRequests() async {
    if (DummyJointOrderStore.pendingRequestsForbidden) {
      return {'success': true, 'data': <Map<String, dynamic>>[]};
    }

    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      final deliveryPosts = await _getDeliveryPosts();
      final userNickname = await ApiService.getUserNickname() ?? '익명';

      // 현재 사용자가 작성한 게시글 ID 목록
      final userPostIds = deliveryPosts
          .where((post) => post['userName'] == userNickname)
          .map((post) => post['id'].toString())
          .toList();

      // 현재 사용자의 게시글을 대상으로 한 요청 찾기
      final pendingRequests = DummyJointOrderStore.tempJointOrderRequests.where(
        (request) {
          final targetPostIds = List<String>.from(request['target_post_ids']);
          return request['status'] == 'pending' &&
              targetPostIds.any((id) => userPostIds.contains(id));
        },
      ).toList();

      logDebug('[JointOrderApi] 대기 중인 합동 주문 요청: ${pendingRequests.length}개');

      return {'success': true, 'data': pendingRequests};
    }

    // API 연동
    final result = await ApiService.get(
      'api/v1/joint-orders/requests/pending',
      requiresAuth: true,
    );

    if (result['success'] != true && result['statusCode'] == 403) {
      DummyJointOrderStore.pendingRequestsForbidden = true;
      logDebug('[JointOrderApi] pending 요청 조회가 403으로 거부되어 폴링을 중단합니다.');
      return {'success': true, 'data': <Map<String, dynamic>>[]};
    }

    // 서버 응답(camelCase)을 클라이언트 공통 포맷(snake_case)으로 정규화
    if (result['success'] == true && result['data'] is List) {
      final list = List<Map<String, dynamic>>.from(result['data'] as List);
      final normalizedList = list.map((item) {
        final m = Map<String, dynamic>.from(item);

        // id -> request_id
        final rawId = m['id'] ?? m['request_id'];
        if (rawId != null) {
          m['request_id'] = rawId.toString();
        }

        // requesterName -> requester_name
        if (m.containsKey('requesterName') &&
            !m.containsKey('requester_name')) {
          m['requester_name'] = m['requesterName'];
        }

        // requesterPostId -> requester_post_id
        final requesterPostId = m['requester_post_id'] ?? m['requesterPostId'];
        if (requesterPostId != null) {
          m['requester_post_id'] = requesterPostId.toString();
        }

        // targetPostIds -> target_post_ids
        final targetPostIds = m['target_post_ids'] ?? m['targetPostIds'];
        if (targetPostIds is List) {
          m['target_post_ids'] = targetPostIds
              .map((id) => id.toString())
              .toList();
        }

        return m;
      }).toList();

      result['data'] = normalizedList;
    }

    return result;
  }

  /// 합동 주문 매칭 완료 시 그룹 채팅방 생성
  static Future<Map<String, dynamic>> createJointChatRoom({
    required String requestId,
    required List<String> postIds,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      final deliveryPosts = await _getDeliveryPosts();
      final chatRoomId = 'joint_room_${DateTime.now().millisecondsSinceEpoch}';

      // 요청 ID로 원본 요청 데이터 찾기
      final request = DummyJointOrderStore.tempJointOrderRequests.firstWhere(
        (r) => r['id'] == requestId,
        orElse: () => {},
      );

      // 요청자 정보를 방장으로 설정
      final hostId = request['requester_id'] ?? 'unknown_host';
      final hostName = request['requester_name'] ?? '방장';

      // 첫 번째 게시글 정보로 채팅방 기본 정보 설정
      final firstPost = deliveryPosts.firstWhere(
        (p) => p['id'] == postIds[0],
        orElse: () => {},
      );

      // 각 게시글의 실제 인원수 합산 및 최대 모집 인원 중 큰 값 찾기
      int totalCurrentPeople = 0;
      int maxMaxPeople = 0;
      for (final postId in postIds) {
        final post = deliveryPosts.firstWhere(
          (p) => p['id'] == postId,
          orElse: () => {},
        );
        if (post.isNotEmpty) {
          final current = post['current_people'] ?? post['currentPeople'] ?? 1;
          final max = post['max_people'] ?? post['maxPeople'] ?? 1;
          totalCurrentPeople += (current is int)
              ? current
              : int.tryParse(current.toString()) ?? 1;
          final maxInt = (max is int) ? max : int.tryParse(max.toString()) ?? 1;
          if (maxInt > maxMaxPeople) {
            maxMaxPeople = maxInt;
          }
        }
      }
      // 현재 인원이 최대 인원보다 많으면 최대 인원을 현재 인원으로 조정
      if (totalCurrentPeople > maxMaxPeople) {
        maxMaxPeople = totalCurrentPeople;
      }

      final newChatRoom = {
        'id': chatRoomId,
        'host_id': hostId, // 요청자가 방장이 되도록 수정
        'host_name': hostName,
        'post_title': '합동 주문: ${firstPost['store_name'] ?? '가게'}',
        'post_type': '주문전', // 채팅방 초기 상태
        'location':
            '${firstPost['store_name'] ?? ''} / ${firstPost['delivery_place'] ?? ''}',
        'last_message': '합동 주문 채팅방이 생성되었습니다',
        'last_message_time': '방금',
        'current_people': totalCurrentPeople,
        'max_people': maxMaxPeople,
        'has_unread': true,
      };

      DummyDataCache.tempChatRoomsList.insert(0, newChatRoom);

      // 요청 데이터에 채팅방 ID 저장 (나중에 조회용)
      final requestIndex = DummyJointOrderStore.tempJointOrderRequests
          .indexWhere((r) => r['id'] == requestId);
      if (requestIndex != -1) {
        DummyJointOrderStore
                .tempJointOrderRequests[requestIndex]['chat_room_id'] =
            chatRoomId;
      }


      // 모든 참여자들에게 알림 (게시글 생성자 + 일반 참여자)
      await notifyAllParticipants(chatRoomId: chatRoomId, postIds: postIds);

      return {
        'success': true,
        'data': {
          'chat_room_id': chatRoomId,
          'message': '합동 주문 매칭이 완료되어 채팅방이 생성되었습니다.',
        },
      };
    }

    // API 연동
    final requestData = {
      'requestId': int.parse(requestId),
      'postIds': postIds.map((id) => int.parse(id)).toList(),
    };

    final response = await ApiService.post(
      'api/v1/joint-orders/create-chat-room',
      requestData,
      requiresAuth: true,
    );

    // 서버 응답(chatRoomId/camelCase)을 클라이언트 공통 포맷(chat_room_id/snake_case)으로 정규화
    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data']);
      final rawChatRoomId = data['chatRoomId'] ?? data['chat_room_id'];
      if (rawChatRoomId != null) {
        data['chat_room_id'] = rawChatRoomId.toString();
        response['data'] = data;
      }
    }

    return response;
  }

  /// 합동 주문 채팅방 정보 가져오기 (채팅방으로 이동하기 위해)
  static Future<Map<String, dynamic>> getJointChatRoomInfo(
    String chatRoomId,
  ) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      // tempChatRoomsList에서 채팅방 정보 찾기
      final chatRoom = DummyDataCache.tempChatRoomsList.firstWhere(
        (room) => room['id'] == chatRoomId,
        orElse: () => <String, dynamic>{},
      );

      if (chatRoom.isEmpty) {
        return {'success': false, 'message': '채팅방 정보를 찾을 수 없습니다.'};
      }


      return {'success': true, 'data': chatRoom};
    }

    // API 연동
    return await ApiService.get(
      'api/v1/chat/rooms/$chatRoomId',
      requiresAuth: true,
    );
  }

  // 헬퍼 메서드: PostApi의 임시 배달 게시글 가져오기 (개발 모드용)
  static Future<List<Map<String, dynamic>>> _getDeliveryPosts() async {
    // 개발 모드에서는 PostApi의 임시 데이터를 직접 사용해야 함
    final result = await PostApi.getDeliveryPosts();
    if (result['success'] == true) {
      return List<Map<String, dynamic>>.from(result['data'] ?? []);
    }
    return [];
  }

  // 헬퍼 메서드: 사용자 ID 가져오기
  // ignore: unused_element
  static Future<String> _getUserId() async {
    final token = await ApiService.getToken();
    return ApiService.getUserIdFromTokenValue(token) ??
        'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  // 헬퍼 메서드: 현재 사용자 정보(ID, 닉네임) 가져오기
  static Future<(String userId, String userNickname)>
  _getCurrentUserInfo() async {
    final userId = await ApiService.getUserId() ?? 'unknown_user';
    final userNickname = await ApiService.getUserNickname() ?? '익명';
    return (userId, userNickname);
  }

  // 테스트용 자동 응답 로직
  static void _autoRespondToTestPosts(
    String requestId,
    List<String> targetPostIds,
  ) {
    // 비동기 작업을 별도로 실행
    Future.delayed(const Duration(milliseconds: 1500), () async {
      // 두 개의 테스트 게시글을 모두 선택한 경우, 타임아웃 테스트를 위해 아무것도 하지 않음
      if (targetPostIds.contains('test_accept_post') &&
          targetPostIds.contains('test_reject_post')) {
        logDebug('[JointOrderApi] 자동 응답 건너뛰기 (타임아웃 테스트 시나리오)');
        return;
      }

      final requestIndex = DummyJointOrderStore.tempJointOrderRequests
          .indexWhere((r) => r['id'] == requestId);
      if (requestIndex == -1) return;

      for (final postId in targetPostIds) {
        bool shouldAccept = false;
        String responderName = '익명';

        // test_accept_post는 자동 수락
        if (postId == 'test_accept_post') {
          shouldAccept = true;
          responderName = '수락자';
        }
        // test_reject_post는 자동 거절
        else if (postId == 'test_reject_post') {
          shouldAccept = false;
          responderName = '거절자';
        } else {
          // 다른 게시글은 자동 응답하지 않음
          continue;
        }

        // 응답 추가
        final response = {
          'request_id': requestId,
          'post_id': postId,
          'responder_id': 'auto_responder_$postId',
          'responder_name': responderName,
          'accepted': shouldAccept,
          'response_time': DateTime.now().toIso8601String(),
        };

        final responses = List<Map<String, dynamic>>.from(
          DummyJointOrderStore
                  .tempJointOrderRequests[requestIndex]['responses'] ??
              [],
        );
        responses.add(response);
        DummyJointOrderStore.tempJointOrderRequests[requestIndex]['responses'] =
            responses;

        // 모든 대상 게시글에서 응답이 왔는지 확인
        if (responses.length >= targetPostIds.length) {
          final allAccepted = responses.every((r) => r['accepted'] == true);

          if (allAccepted) {
            DummyJointOrderStore
                    .tempJointOrderRequests[requestIndex]['status'] =
                'accepted';
            logDebug('[JointOrderApi] 모든 게시글 작성자가 수락 - 매칭 성공!');
          } else {
            DummyJointOrderStore
                    .tempJointOrderRequests[requestIndex]['status'] =
                'rejected';
            logDebug('[JointOrderApi] 일부 거절 - 매칭 실패');
          }
        }
      }
    });
  }

  // Mock responder scenario for local-only test data
  static Future<void> _createTestChatRoomForResponder(String requestId) async {
    final requestIndex = DummyJointOrderStore.tempJointOrderRequests.indexWhere(
      (r) => r['id'] == requestId,
    );
    if (requestIndex == -1) return;

    final request = DummyJointOrderStore.tempJointOrderRequests[requestIndex];
    final requesterPostId = request['requester_post_id'];
    final responderPostId = 'test_pending_request_post';

    final result = await createJointChatRoom(
      requestId: requestId,
      postIds: [requesterPostId, responderPostId],
    );

    if (result['success'] == true) {
      final chatRoomId = result['data']['chat_room_id'];
      // 공용 장바구니 즉시 활성화
      await SharedCartApi.activateSharedCart(roomId: chatRoomId);
    }
  }

  /// 요청 타임아웃 처리 (일정 시간 후 미응답자는 자동 거절)
  static void _startRequestTimeout(String requestId, int timeoutSeconds) {
    Future.delayed(Duration(seconds: timeoutSeconds), () async {
      final requestIndex = DummyJointOrderStore.tempJointOrderRequests
          .indexWhere((r) => r['id'] == requestId);
      if (requestIndex == -1) return;

      final request = DummyJointOrderStore.tempJointOrderRequests[requestIndex];

      // 이미 완료된 요청은 무시
      if (request['status'] != 'pending') return;

      final targetPostIds = List<String>.from(request['target_post_ids']);
      final responses = List<Map<String, dynamic>>.from(
        request['responses'] ?? [],
      );

      // 응답한 게시글 ID 목록
      final respondedPostIds = responses
          .map((r) => r['post_id'].toString())
          .toSet();

      // 미응답 게시글이 있는지 확인
      final hasUnresponsive = targetPostIds.any(
        (id) => !respondedPostIds.contains(id),
      );

      if (hasUnresponsive) {
        // 타임아웃으로 자동 거절 처리
        DummyJointOrderStore.tempJointOrderRequests[requestIndex]['status'] =
            'timeout';
      }
    });
  }

  /// 게시글의 모든 참여자 닉네임 가져오기
  static Future<List<String>> _getPostParticipants(String postId) async {
    final deliveryPosts = await _getDeliveryPosts();
    final post = deliveryPosts.firstWhere(
      (p) => p['id'] == postId,
      orElse: () => <String, dynamic>{},
    );

    if (post.isEmpty) return [];

    final participants = post['participants'];
    if (participants is List) {
      return participants.map((p) => p.toString()).toList();
    }

    return [];
  }

  /// 매칭 완료 시 모든 참여자들에게 알림 (게시글 생성자 포함)
  /// 이 함수는 채팅방 생성 후 호출되어야 함
  static Future<void> notifyAllParticipants({
    required String chatRoomId,
    required List<String> postIds,
  }) async {
    if (!ApiService.isDevelopment) return;

    // 각 게시글의 모든 참여자 수집
    final allParticipants = <String>{};

    for (final postId in postIds) {
      final participants = await _getPostParticipants(postId);
      allParticipants.addAll(participants);
    }


    // 실제 앱에서는 여기서 각 사용자에게 푸시 알림을 보내거나
    // 알림 목록에 추가하는 로직이 들어갈 것
    // 개발 모드에서는 로그만 출력
  }
}
