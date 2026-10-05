// 공용 장바구니 관련 API 관리
import 'package:delivery/utils/logging.dart';
import 'api.dart';
import '../dummy_data/dummy.dart';

class SharedCartApi {
  /// 공용 장바구니 활성화 (방장만 가능)
  static Future<Map<String, dynamic>> activateSharedCart({
    required String roomId,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      // (개발용) 해당 채팅방의 장바구니를 활성화 상태로 변경
      DummyDataCache.tempSharedCartActiveState[roomId] = true;

      // 활성화된 장바구니를 임시 저장 (영수증 확인용)
      DummyDataCache.tempReceipts.remove(roomId); // 기존 영수증 제거

      // 채팅방 상태를 '주문중'으로 변경
      DummyDataCache.tempChatRoomStatus[roomId] = '주문중';

      return {
        'success': true,
        'data': {
          'id': 'cart_${DateTime.now().millisecondsSinceEpoch}',
          'room_id': roomId,
          'is_active': true,
          'items': [],
          'host_id': 'me',
        },
      };
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/shared-cart/activate',
      {},
      requiresAuth: true,
    );
  }

  /// 공용 장바구니 상태 조회
  static Future<Map<String, dynamic>> getSharedCart({
    required String roomId,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 200));

      // (개발용) 임시 저장된 활성화 상태를 가져옴 (없으면 false)
      final bool isActive =
          DummyDataCache.tempSharedCartActiveState[roomId] ?? false;

      // 저장된 메뉴 아이템들 가져오기
      final items = DummyDataCache.tempSharedCartItems[roomId] ?? [];

      return {
        'success': true,
        'data': {
          'id': 'cart_$roomId',
          'room_id': roomId,
          'is_active': isActive,
          'items': items,
          'host_id': 'me',
        },
      };
    }

    return await ApiService.get(
      'api/v1/chat/rooms/$roomId/shared-cart',
      requiresAuth: true,
    );
  }

  /// 메뉴 추가
  static Future<Map<String, dynamic>> addMenuItem({
    required String roomId,
    required String name,
    required int price,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      // 현재 로그인한 사용자 정보 가져오기
      final userId = await ApiService.getUserId() ?? 'me';
      final userNickname = await ApiService.getUserNickname() ?? '나';

      final newItem = {
        'id': 'item_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'price': price,
        'user_id': userId,
        'user_nickname': userNickname,
      };

      // 임시 저장소에 메뉴 아이템 추가
      if (!DummyDataCache.tempSharedCartItems.containsKey(roomId)) {
        DummyDataCache.tempSharedCartItems[roomId] = [];
      }
      DummyDataCache.tempSharedCartItems[roomId]!.add(newItem);

      logDebug('[SharedCartApi] Mock cart item added');
      return {'success': true, 'data': newItem};
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/shared-cart/items',
      {'name': name, 'price': price},
      requiresAuth: true,
    );
  }

  /// 메뉴 수정 (자신의 메뉴 or 방장은 모든 메뉴)
  static Future<Map<String, dynamic>> updateMenuItem({
    required String roomId,
    required String itemId,
    required String name,
    required int price,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      // 임시 저장소에서 메뉴 아이템 수정
      if (DummyDataCache.tempSharedCartItems.containsKey(roomId)) {
        final items = DummyDataCache.tempSharedCartItems[roomId]!;
        final index = items.indexWhere((item) => item['id'] == itemId);
        if (index != -1) {
          items[index]['name'] = name;
          items[index]['price'] = price;
        }
      }

      logDebug('[SharedCartApi] Mock cart item updated');
      return {
        'success': true,
        'data': {'id': itemId, 'name': name, 'price': price},
      };
    }

    return await ApiService.put(
      'api/v1/chat/rooms/$roomId/shared-cart/items/$itemId',
      {'name': name, 'price': price},
      requiresAuth: true,
    );
  }

  /// 메뉴 삭제 (자신의 메뉴 or 방장은 모든 메뉴)
  static Future<Map<String, dynamic>> deleteMenuItem({
    required String roomId,
    required String itemId,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      // 임시 저장소에서 메뉴 아이템 삭제
      if (DummyDataCache.tempSharedCartItems.containsKey(roomId)) {
        DummyDataCache.tempSharedCartItems[roomId]!.removeWhere(
          (item) => item['id'] == itemId,
        );
      }

      logDebug('[SharedCartApi] Mock cart item removed');
      return {'success': true};
    }

    return await ApiService.delete(
      'api/v1/chat/rooms/$roomId/shared-cart/items/$itemId',
      requiresAuth: true,
    );
  }

  /// 공용 장바구니 완료 (방장만 가능)
  static Future<Map<String, dynamic>> completeSharedCart({
    required String roomId,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));
      logDebug('[SharedCartApi] Mock cart completed');

      // 현재 사용자 정보 가져오기
      final currentUserId = await ApiService.getUserId() ?? 'me';
      final hostNickname = await ApiService.getUserNickname() ?? '나';

      // 고정 더미 영수증 데이터 (room_1용)
      final fixedItems = [
        {
          'id': 'item_fixed_1',
          'name': '후라이드 치킨',
          'price': 18000,
          'user_id': currentUserId,
          'user_nickname': hostNickname,
        },
        {
          'id': 'item_fixed_2',
          'name': '양념 치킨',
          'price': 19000,
          'user_id': 'user_2',
          'user_nickname': '치킨러버',
        },
        {
          'id': 'item_fixed_3',
          'name': '콜라 1.5L',
          'price': 3000,
          'user_id': currentUserId,
          'user_nickname': hostNickname,
        },
      ];

      final totalPrice = 40000;
      const deliveryFee = 3000;

      // 영수증 데이터 생성
      final receiptData = {
        'cart_id': 'cart_$roomId',
        'items': fixedItems,
        'total_price': totalPrice,
        'delivery_fee': deliveryFee,
        'host_id': currentUserId,
        'host_nickname': hostNickname,
        'created_at': DateTime.now().toIso8601String(),
      };

      // 영수증 저장 (chat_room_page.dart에서 읽는 형식)
      DummyDataCache.tempReceipts[roomId] = {
        'sender_id': 'system',
        'sender_name': '시스템',
        'message': '주문이 완료되었습니다! 아래 영수증을 확인해주세요.',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'receipt',
        'cart_summary': receiptData,
      };

      // 장바구니 비활성화
      DummyDataCache.tempSharedCartActiveState[roomId] = false;

      // 채팅방 상태를 '주문중'으로 변경
      DummyDataCache.tempChatRoomStatus[roomId] = '주문중';

      logDebug('[SharedCartApi] Mock receipt created');

      return {'success': true, 'data': receiptData};
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/shared-cart/complete',
      {},
      requiresAuth: true,
    );
  }

  /// 포인트 결제 (정산하기)
  static Future<Map<String, dynamic>> transferPayment({
    required String roomId,
    required String cartId,
    required List<Map<String, dynamic>> transfers,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));
      logDebug('[SharedCartApi] Mock payment transfer completed');

      if (transfers.isEmpty) {
        return {'success': false, 'message': '정산 대상이 비어 있습니다.'};
      }

      return {
        'success': true,
        'message': '결제가 완료되었습니다',
        'data': {'cartId': cartId, 'roomId': roomId, 'results': transfers},
      };
    }

    final parsedCartId = int.tryParse(cartId);
    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/settlement/transfer',
      {'cartId': parsedCartId ?? cartId, 'transfers': transfers},
      requiresAuth: true,
    );
  }

  /// 결제 요청 생성 (참여자/방장 공통)
  static Future<Map<String, dynamic>> createSettlementRequest({
    required String roomId,
    required String cartId,
    required int amount,
    int? deliveryFeeShare,
    String? memo,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      final requesterId = await ApiService.getUserId() ?? 'me';
      final requesterNickname = await ApiService.getUserNickname() ?? '나';
      final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';

      final request = {
        'request_id': requestId,
        'room_id': roomId,
        'cart_id': cartId,
        'requester_id': requesterId,
        'requester_nickname': requesterNickname,
        'amount': amount,
        if (deliveryFeeShare != null) 'delivery_fee_share': deliveryFeeShare,
        'status': 'PENDING',
        if (memo != null && memo.trim().isNotEmpty) 'memo': memo.trim(),
        'requested_at': DateTime.now().toIso8601String(),
      };

      DummyDataCache.tempSettlementRequests.putIfAbsent(roomId, () => []);
      // 동일 사용자의 기존 대기 요청 제거
      DummyDataCache.tempSettlementRequests[roomId]!.removeWhere(
        (item) => item['requester_id'] == requesterId,
      );
      DummyDataCache.tempSettlementRequests[roomId]!.add(request);

      return {'success': true, 'data': request};
    }

    final payload = <String, dynamic>{
      'amount': amount,
      if (memo != null && memo.trim().isNotEmpty) 'memo': memo.trim(),
      if (deliveryFeeShare != null && deliveryFeeShare >= 0)
        'deliveryFeeShare': deliveryFeeShare,
    };

    final parsedCartId = int.tryParse(cartId);
    if (parsedCartId != null) {
      payload['cartId'] = parsedCartId;
    } else if (cartId.isNotEmpty) {
      payload['cartId'] = cartId;
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/settlement/transfer/requests',
      payload,
      requiresAuth: true,
    );
  }

  /// 결제 요청 목록 조회 (방 참여자 누구나)
  static Future<Map<String, dynamic>> getSettlementRequests({
    required String roomId,
    String? cartId,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 200));
      final requests = DummyDataCache.tempSettlementRequests[roomId] ?? [];
      return {
        'success': true,
        'data': {'requests': requests},
      };
    }

    final query = <String>[];
    final parsedCartId = cartId != null ? int.tryParse(cartId) : null;
    if (parsedCartId != null) {
      query.add('cartId=$parsedCartId');
    }

    final queryString = query.isEmpty ? '' : '?${query.join('&')}';

    return await ApiService.get(
      'api/v1/chat/rooms/$roomId/settlement/transfer/requests$queryString',
      requiresAuth: true,
    );
  }

  /// 결제 요청 승인 (방장 전용)
  static Future<Map<String, dynamic>> approveSettlementRequest({
    required String roomId,
    required String requestId,
    String? decisionMemo,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));
      final requests = DummyDataCache.tempSettlementRequests[roomId];
      if (requests == null) {
        return {'success': false, 'message': '요청을 찾을 수 없습니다.'};
      }

      final index = requests.indexWhere(
        (item) => item['request_id'] == requestId,
      );
      if (index == -1) {
        return {'success': false, 'message': '요청을 찾을 수 없습니다.'};
      }

      requests[index]['status'] = 'APPROVED';
      requests[index]['processed_at'] = DateTime.now().toIso8601String();
      if (decisionMemo != null && decisionMemo.trim().isNotEmpty) {
        requests[index]['decision_memo'] = decisionMemo.trim();
      }

      return {'success': true, 'data': requests[index]};
    }

    final body = <String, dynamic>{};
    if (decisionMemo != null && decisionMemo.trim().isNotEmpty) {
      body['decisionMemo'] = decisionMemo.trim();
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/settlement/transfer/requests/$requestId/approve',
      body.isEmpty ? null : body,
      requiresAuth: true,
    );
  }

  /// 결제 요청 거절 또는 취소 (방장/요청자)
  static Future<Map<String, dynamic>> rejectSettlementRequest({
    required String roomId,
    required String requestId,
    String? decisionMemo,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));
      final requests = DummyDataCache.tempSettlementRequests[roomId];
      if (requests == null) {
        return {'success': false, 'message': '요청을 찾을 수 없습니다.'};
      }

      final index = requests.indexWhere(
        (item) => item['request_id'] == requestId,
      );
      if (index == -1) {
        return {'success': false, 'message': '요청을 찾을 수 없습니다.'};
      }

      requests[index]['status'] = 'REJECTED';
      requests[index]['processed_at'] = DateTime.now().toIso8601String();
      if (decisionMemo != null && decisionMemo.trim().isNotEmpty) {
        requests[index]['decision_memo'] = decisionMemo.trim();
      }

      return {'success': true, 'data': requests[index]};
    }

    final body = <String, dynamic>{};
    if (decisionMemo != null && decisionMemo.trim().isNotEmpty) {
      body['decisionMemo'] = decisionMemo.trim();
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/settlement/transfer/requests/$requestId/reject',
      body.isEmpty ? null : body,
      requiresAuth: true,
    );
  }
}
