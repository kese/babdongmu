/// 채팅방 목록에서 사용할 채팅방 하나의 데이터 구조
/// 서버 연동 전 더미 데이터로 사용 가능
library;

class ChatRoomList {
  final String id; // 채팅방 고유 ID
  final String postTitle; // 게시글 제목 (또는 채팅방 이름)
  final String postType; // UI에 표시할 상태 라벨 (주문전/주문중/배달중/합동방)
  final String roomType; // 서버에서 내려주는 roomType (delivery/meet/group 등)
  final String storeName; // 음식점/가게 이름
  final String location; // 장소 (배달 장소 또는 만날 장소)
  final String lastMessage; // 마지막 메시지 내용
  final String lastMessageTime; // 마지막 메시지 시간
  final int currentPeople; // 현재 참여 인원
  final int maxPeople; // 최대 인원
  final bool hasUnread; // 읽지 않은 메시지 여부 (선택사항)

  ChatRoomList({
    required this.id,
    required this.postTitle,
    required this.postType,
    this.roomType = '',
    this.storeName = '',
    required this.location,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.currentPeople,
    required this.maxPeople,
    this.hasUnread = false,
  });

  // JSON 데이터를 ChatRoom 객체로 변환
  factory ChatRoomList.fromJson(Map<String, dynamic> json) {
    final postTypeRaw =
        _pickString([
          json['post_type'],
          json['postType'],
          json['roomType'],
          json['postTypeCode'],
        ]) ??
        '';

    final statusRaw = _pickString([
      json['status'],
      json['roomStatus'],
      json['postStatus'],
      json['post_state'],
      json['phase'],
      json['roomPhase'],
    ]);
    final postData = _asMap(json['post']);
    final roomTypeRaw =
        _pickString([
          json['room_type'],
          json['roomType'],
          json['room_category'],
          postData?['room_type'],
          postData?['roomType'],
        ]) ??
        '';
    final normalizedRoomType = roomTypeRaw.trim().toLowerCase();
    final participantsList = _asList(
      json['participants'] ??
          json['participantList'] ??
          json['members'] ??
          json['participantUsers'] ??
          postData?['participants'],
    );

    final lastMessageTimeRaw = _pickString([
      json['last_message_time'],
      json['lastMessageTime'],
      json['lastMessageTimestamp'],
      json['lastMessageAt'],
    ]);

    final currentPeople = _firstInt([
      json['current_people'],
      json['currentPeople'],
      json['current_participants'],
      json['currentParticipants'],
      json['currentMemberCount'],
      json['participantCount'],
      json['memberCount'],
      postData?['currentParticipants'],
      postData?['current_people'],
    ]);

    final maxPeople = _firstInt([
      json['max_people'],
      json['maxPeople'],
      json['max_participants'],
      json['maxParticipants'],
      json['participantLimit'],
      json['capacity'],
      json['maxMemberCount'],
      json['postMaxParticipants'],
      postData?['maxParticipants'],
      postData?['max_people'],
    ], defaultValue: participantsList?.length ?? currentPeople);

    final resolvedCurrent = currentPeople > 0
        ? currentPeople
        : (participantsList?.length ?? currentPeople);

    int resolvedMax = maxPeople;
    if (resolvedMax == 0 && participantsList != null) {
      resolvedMax = participantsList.length;
    }
    if (resolvedMax > 0 && resolvedCurrent > resolvedMax) {
      resolvedMax = resolvedCurrent;
    }

    final unreadCount = _firstInt([json['unread_count'], json['unreadCount']]);

    final storeName =
        _pickString([
          // 최상위 레벨
          json['restaurantName'],
          json['restaurant_name'],
          json['storeName'],
          json['store_name'],
          // post 객체 내부
          postData?['restaurantName'],
          postData?['restaurant_name'],
          postData?['storeName'],
          postData?['store_name'],
          // 기타 가능한 키
          json['shopName'],
          json['shop_name'],
          postData?['shopName'],
          postData?['shop_name'],
        ]) ??
        '';

    final rawLocation =
        _pickString([
          json['location'],
          json['meetingPlace'],
          json['meeting_place'],
          json['deliveryPlace'],
          json['delivery_address'],
        ]) ??
        '';

    return ChatRoomList(
      id:
          _pickString([
            json['id'],
            json['roomId'],
            json['room_id'],
          ])?.toString() ??
          'unknown_id',
      postTitle:
          _pickString([
            json['post_title'],
            json['postTitle'],
            json['title'],
            json['roomName'],
            json['room_name'],
            postData?['postTitle'],
          ]) ??
          '',
      postType: _resolveDisplayStatus(
        statusRaw,
        postTypeRaw,
        normalizedRoomType,
      ),
      roomType: normalizedRoomType,
      storeName: storeName,
      location: rawLocation,
      lastMessage:
          _pickString([
            json['last_message'],
            json['lastMessage'],
            json['recentMessage'],
            json['lastMessageContent'],
          ]) ??
          '',
      lastMessageTime: _formatTime(lastMessageTimeRaw),
      currentPeople: resolvedCurrent,
      maxPeople: resolvedMax > 0 ? resolvedMax : resolvedCurrent,
      hasUnread: unreadCount > 0
          ? true
          : _parseBool(json['has_unread'] ?? json['hasUnread']),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static List<dynamic>? _asList(dynamic value) {
    if (value is List) return value;
    return null;
  }

  static String? _pickString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate;
      }
      if (candidate is int || candidate is double) {
        return candidate.toString();
      }
    }
    return null;
  }

  static int _firstInt(List<dynamic> candidates, {int defaultValue = 0}) {
    for (final candidate in candidates) {
      final parsed = _parseInt(candidate, defaultValue: -1);
      if (parsed != -1) {
        return parsed;
      }
    }
    return defaultValue;
  }

  // 안전한 정수 변환 함수
  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '');
      final asInt = int.tryParse(cleaned);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(cleaned);
      if (asDouble != null) return asDouble.round();
      return defaultValue;
    }
    return defaultValue;
  }

  // 안전한 불리언 변환 함수
  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return defaultValue;
  }

  static String _resolveDisplayStatus(
    String? statusRaw,
    String postTypeRaw,
    String roomTypeRaw,
  ) {
    if (roomTypeRaw == 'group') {
      return '합동방';
    }

    if (_isMeetType(roomTypeRaw)) {
      return '';
    }

    final fromStatus = statusRaw != null ? _normalizeStatus(statusRaw) : null;
    if (fromStatus != null && fromStatus.isNotEmpty) {
      return fromStatus;
    }
    final preferredType = postTypeRaw.isNotEmpty ? postTypeRaw : roomTypeRaw;
    return _normalizePostType(preferredType);
  }

  static bool _isMeetType(String raw) {
    if (raw.isEmpty) return false;
    final upper = raw.toUpperCase();
    return {
      'MEET',
      'MEET_ROOM',
      'FRIEND',
      'MEETING',
      'PREPARE',
      'PREPARING',
    }.contains(upper);
  }

  static String? _normalizeStatus(String raw) {
    if (raw.isEmpty) return null;
    final upper = raw.toUpperCase();

    // DOCS_API_HELPER.md §6.1.1 기준 (2025-11-19 업데이트)
    if (upper == 'BEFORE_ORDER') {
      return '주문전';
    }
    if (upper == 'ORDERING') {
      return '주문중';
    }
    if (upper == 'DELIVERING') {
      return '배달중';
    }
    if (upper == 'COMPLETED') {
      return '완료';
    }
    if (upper == 'DISPUTED') {
      return '신고접수';
    }

    // 레거시 호환성 유지
    if (upper == 'ACTIVE') {
      return '주문전';
    }
    if (upper == 'CLOSED') {
      return '주문중';
    }

    if ({
      'ORDER_BEFORE',
      'ORDER_PENDING',
      'READY',
      'OPEN',
      'RECRUITING',
      'GATHERING',
      'READY_TO_PAY',
    }.contains(upper)) {
      return '주문전';
    }

    if ({
      'ORDER_IN_PROGRESS',
      'ORDER_PROGRESS',
      'ORDER_STARTED',
      'PREPARING_ORDER',
      'IN_ORDER',
      'READY_TO_START',
    }.contains(upper)) {
      return '주문중';
    }

    if ({
      'DELIVERY',
      'DELIVERY_IN_PROGRESS',
      'ON_DELIVERY',
      'DELIVERY_STARTED',
      'ARRIVING',
      'IN_PROGRESS',
    }.contains(upper)) {
      return '배달중';
    }

    if ({'COMPLETED_ORDER', 'DONE', 'FINISHED'}.contains(upper)) {
      return '완료';
    }

    if ({'REPORTED', 'ISSUE_REPORTED', 'HAS_ISSUE'}.contains(upper)) {
      return '신고접수';
    }

    return null;
  }

  static String _normalizePostType(String raw) {
    if (raw.isEmpty) return '';
    final upper = raw.toUpperCase();
    if ({
      'DELIVERY',
      'DELIVERY_POST',
      'DELIVER',
      'DELIVERY_IN_PROGRESS',
    }.contains(upper)) {
      return '배달중';
    }
    if ({
      'ORDERING',
      'ORDER',
      'ORDER_IN_PROGRESS',
      'IN_ORDER',
    }.contains(upper)) {
      return '주문중';
    }
    if ({'MEET', 'FRIEND', 'MEETING', 'PREPARE', 'PREPARING'}.contains(upper)) {
      return '주문전';
    }
    return raw;
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final now = DateTime.now();
      final difference = now.difference(parsed);
      if (difference.inMinutes < 1) return '방금';
      if (difference.inHours < 1) {
        return '${difference.inMinutes}분 전';
      }
      if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      }
      return '${parsed.month}/${parsed.day}';
    }
    return raw;
  }

  ChatRoomList copyWith({
    String? lastMessage,
    String? lastMessageTime,
    String? roomType,
    String? storeName,
    bool? hasUnread,
  }) {
    return ChatRoomList(
      id: id,
      postTitle: postTitle,
      postType: postType,
      roomType: roomType ?? this.roomType,
      storeName: storeName ?? this.storeName,
      location: location,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      currentPeople: currentPeople,
      maxPeople: maxPeople,
      hasUnread: hasUnread ?? this.hasUnread,
    );
  }
}
