// 채팅 관련 API 관리
import 'package:delivery/utils/logging.dart';
import 'api.dart';
import '../dummy_data/dummy.dart';

class ChatApi {
  /// 채팅방 정보 가져오기 (개발용 - room_1, room_2)
  static Future<Map<String, dynamic>> getChatRoomInfo(String chatRoomId) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));

      // 고정 더미 채팅방 처리 (room_1, room_2)
      if (chatRoomId == 'room_1' || chatRoomId == 'room_2') {
        final currentUserId = await ApiService.getUserId() ?? 'me';
        final nickname = await ApiService.getUserNickname() ?? '나';

        final fixedRooms = {
          'room_1': {
            'id': 'room_1',
            'host_id': currentUserId, // 내가 방장
            'host_name': nickname,
            'post_title': '치킨 같이 시키실 분!',
            'location': 'BBQ 치킨',
          },
          'room_2': {
            'id': 'room_2',
            'host_id': 'host_user_1', // 다른 사람이 방장
            'host_name': '피자왕',
            'post_title': '피자 배달 같이해요',
            'location': '도미노피자',
          },
        };

        return {'success': true, 'data': fixedRooms[chatRoomId]};
      }

      return {'success': false, 'message': '채팅방 정보를 찾을 수 없습니다.'};
    }

    return await ApiService.get(
      'api/v1/chat/rooms/$chatRoomId',
      requiresAuth: true,
    );
  }

  /// 채팅방 목록 가져오기
  static Future<Map<String, dynamic>> getChatRooms() async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(seconds: 1));

      // room_2 공용장바구니 활성화 상태로 초기화
      _initializeRoom2CartIfNeeded();

      // 현재 사용자 ID 가져오기
      final currentUserId = await ApiService.getUserId() ?? 'me';

      // 더미 채팅방 데이터
      final List<Map<String, dynamic>> fixedData = [
        {
          'id': 'room_1',
          'post_title': '치킨 같이 시키실 분!',
          'post_type': DummyDataCache.tempChatRoomStatus['room_1'] ?? '주문전',
          'location': 'BBQ 치킨',
          'last_message': DummyDataCache.tempChatRoomStatus['room_1'] == '배달중'
              ? '영수증이 공유되었습니다'
              : '좋아요! 메뉴 골라봅시다',
          'last_message_time': '3분 전',
          'current_people': 2,
          'max_people': 4,
          'has_unread': false,
          'host_id': currentUserId, // 내가 방장 - 실제 user_id 사용
        },
        {
          'id': 'room_2',
          'post_title': '피자 배달 같이해요',
          'post_type': DummyDataCache.tempChatRoomStatus['room_2'] ?? '주문중',
          'location': '도미노피자',
          'last_message': '저도 참여합니다',
          'last_message_time': '10분 전',
          'current_people': 3,
          'max_people': 3,
          'has_unread': false,
          'host_id': 'host_user_1', // 다른 사람이 방장 (참여자)
        },
      ];

      return {
        'success': true,
        'data': [...DummyDataCache.tempChatRoomsList, ...fixedData],
      };
    }

    // 실서버 경로는 /api/v1/chat/rooms
    final result = await ApiService.get(
      'api/v1/chat/rooms',
      requiresAuth: true,
    );

    if (result['success'] != true) {
      return result;
    }

    final normalizedRooms = _normalizeRooms(result['data']);
    final meta = _extractMeta(result['data']);

    return {
      'success': true,
      'data': normalizedRooms,
      if (meta != null) 'meta': meta,
    };
  }

  static Future<Map<String, dynamic>> getChatMessages(
    String roomId, {
    String? cursorMessageId,
    int? size,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 500));

      final now = DateTime.now();

      // 더미 데이터 1 (roomId: '1') - 내가 방장, 일반 메시지만
      final List<Map<String, dynamic>> room1Messages = [
        {
          'sender_id': 'user_2',
          'sender_name': '치킨러버',
          'message': '안녕하세요! 참여했어요',
          'timestamp': now
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
          'is_me': false,
        },
        {
          'sender_id': 'me',
          'sender_name': '나',
          'message': '네 환영합니다!',
          'timestamp': now
              .subtract(const Duration(minutes: 4))
              .toIso8601String(),
          'is_me': true,
        },
        {
          'sender_id': 'user_2',
          'sender_name': '치킨러버',
          'message': '좋아요! 메뉴 골라봅시다',
          'timestamp': now
              .subtract(const Duration(minutes: 3))
              .toIso8601String(),
          'is_me': false,
        },
      ];

      // 더미 데이터 2 (roomId: '2') - 내가 방장 아님, 일반 메시지만
      final List<Map<String, dynamic>> room2Messages = [
        {
          'sender_id': 'host_user_1',
          'sender_name': '피자왕',
          'message': '안녕하세요~',
          'timestamp': now
              .subtract(const Duration(minutes: 30))
              .toIso8601String(),
          'is_me': false,
        },
        {
          'sender_id': 'me',
          'sender_name': '나',
          'message': '안녕하세요!',
          'timestamp': now
              .subtract(const Duration(minutes: 29))
              .toIso8601String(),
          'is_me': true,
        },
        {
          'sender_id': 'user_3',
          'sender_name': '치즈좋아',
          'message': '저도 참여합니다',
          'timestamp': now
              .subtract(const Duration(minutes: 28))
              .toIso8601String(),
          'is_me': false,
        },
      ];

      // roomId에 따라 적절한 데이터 반환
      List<Map<String, dynamic>> messagesToReturn = [];
      switch (roomId) {
        case 'room_1':
        case '1':
          messagesToReturn = room1Messages;
          break;
        case 'room_2':
        case '2':
          messagesToReturn = room2Messages;
          break;
        default:
          messagesToReturn = room1Messages; // 기본값
      }

      // tempChatMessages에 추가된 메시지 포함
      if (DummyDataCache.tempChatMessages.containsKey(roomId)) {
        messagesToReturn = [
          ...messagesToReturn,
          ...DummyDataCache.tempChatMessages[roomId]!,
        ];
      }

      return {'success': true, 'data': messagesToReturn};
    }

    final queryParams = <String>[];
    if (cursorMessageId != null && cursorMessageId.isNotEmpty) {
      queryParams.add('cursorMessageId=$cursorMessageId');
    }
    if (size != null) {
      queryParams.add('size=$size');
    }

    final queryString = queryParams.isEmpty ? '' : '?${queryParams.join('&')}';

    final result = await ApiService.get(
      'api/v1/chat/rooms/$roomId/messages$queryString',
      requiresAuth: true,
    );

    if (result['success'] != true) {
      return result;
    }

    final data = result['data'];
    if (data is Map<String, dynamic>) {
      final messages = data['messages'];
      return {
        'success': true,
        'data': messages is List ? messages : <dynamic>[],
        'meta': {'hasNext': data['hasNext'], 'nextCursor': data['nextCursor']},
      };
    }

    if (data is List) {
      return {'success': true, 'data': data};
    }

    return {'success': true, 'data': <dynamic>[]};
  }

  /// 특정 채팅방에 메시지 전송하기
  static Future<Map<String, dynamic>> sendChatMessage({
    required String roomId,
    required String message,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 300));
      logDebug('[ChatApi] Mock message queued');
      return {
        'success': true,
        'data': {'message_id': 'temp_msg_123'},
      };
    }

    /* 현재: message 하나만 서버에 전송.
     서버가 sender_id, timestamp 등 전체 데이터를 요구할 경우 사용
      return await _post(
      'api/v1/chat/rooms/$roomId/messages',
      chatMessage.toJson(),
      requiresAuth: true,
   ); */

    // --- 실제 API 호출 ---
    final trimmed = message.trim();
    return await ApiService.post('api/v1/chat/rooms/$roomId/messages', {
      'messageContent': trimmed,
      'messageType': 'text',
    }, requiresAuth: true);
  }

  /// 채팅방 나가기
  static Future<Map<String, dynamic>> leaveRoom(String roomId) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 400));
      DummyDataCache.tempChatRoomsList.removeWhere(
        (room) => room['id']?.toString() == roomId,
      );
      DummyDataCache.tempChatMessages.remove(roomId);
      DummyDataCache.tempSharedCartItems.remove(roomId);
      DummyDataCache.tempSharedCartActiveState.remove(roomId);
      return {'success': true, 'message': '채팅방에서 나갔습니다.'};
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/leave',
      null,
      requiresAuth: true,
    );
  }
}

List<Map<String, dynamic>> _normalizeRooms(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false)
        .cast<Map<String, dynamic>>();
  }

  if (raw is Map) {
    final map = raw.map((key, value) => MapEntry(key.toString(), value));
    for (final key in ['rooms', 'data', 'list', 'items', 'content']) {
      final value = map[key];
      final normalized = _normalizeRooms(value);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
  }

  return const <Map<String, dynamic>>[];
}

Map<String, dynamic>? _extractMeta(dynamic raw) {
  if (raw is Map) {
    final map = raw.map((key, value) => MapEntry(key.toString(), value));

    for (final key in ['meta', 'page', 'pagination']) {
      final value = map[key];
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
    }

    final meta = <String, dynamic>{};
    for (final key in [
      'total',
      'totalCount',
      'count',
      'page',
      'pageNumber',
      'pageSize',
      'size',
      'hasNext',
      'nextCursor',
    ]) {
      if (map.containsKey(key)) {
        meta[key] = map[key];
      }
    }

    if (meta.isNotEmpty) {
      return meta;
    }
  }

  return null;
}

/// room_2 공용장바구니 활성화 상태로 초기화
void _initializeRoom2CartIfNeeded() {
  const roomId = 'room_2';

  // 이미 초기화되었으면 스킵
  if (DummyDataCache.tempSharedCartActiveState.containsKey(roomId)) {
    return;
  }

  // 채팅방 상태를 '주문중'으로 설정
  DummyDataCache.tempChatRoomStatus[roomId] = '주문중';

  // 공용장바구니 활성화
  DummyDataCache.tempSharedCartActiveState[roomId] = true;

  // 더미 메뉴 아이템들 추가 (방장과 참여자들이 이미 추가한 것처럼)
  final items = [
    {
      'id': 'item_room2_1',
      'name': '페퍼로니 피자 L',
      'price': 25000,
      'user_id': 'host_user_1',
      'user_nickname': '피자왕',
    },
    {
      'id': 'item_room2_2',
      'name': '콜라 1.5L',
      'price': 3000,
      'user_id': 'me',
      'user_nickname': '나',
    },
    {
      'id': 'item_room2_3',
      'name': '치즈 스틱',
      'price': 8000,
      'user_id': 'user_3',
      'user_nickname': '치즈좋아',
    },
  ];

  DummyDataCache.tempSharedCartItems[roomId] = items;

  logDebug('[ChatApi] room_2 공용장바구니 활성화 완료: 총 ${items.length}개 메뉴');
}
