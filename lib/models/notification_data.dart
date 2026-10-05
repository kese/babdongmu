/// 앱 내 알림 데이터 모델
class NotificationData {
  final String id;
  final String
  type; // 'chat_join', 'joint_order_request', 'joint_order_status', etc.
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata; // 추가 정보 (chatRoomId, requestId 등)

  NotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  NotificationData copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationData(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    // id는 int 또는 String으로 올 수 있음
    final id = json['id']?.toString() ?? '';

    // type
    final type = (json['type'] as String?)?.toLowerCase() ?? 'general';

    // title: 서버에서 안 오면 type에서 생성
    final title = json['title'] as String? ?? _getTitleFromType(type);

    // message: 서버에서 안 오면 referenceKey에서 생성
    final message =
        json['message'] as String? ??
        json['body'] as String? ??
        _getMessageFromReference(json['referenceKey'] as String?, type);

    // timestamp: createdAt 또는 timestamp
    DateTime timestamp;
    final timestampStr =
        json['timestamp'] as String? ?? json['createdAt'] as String?;
    if (timestampStr != null) {
      timestamp = DateTime.tryParse(timestampStr) ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }

    return NotificationData(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: json['isRead'] as bool? ?? json['is_read'] as bool? ?? false,
      metadata:
          json['metadata'] as Map<String, dynamic>? ??
          {'referenceKey': json['referenceKey']},
    );
  }

  static String _getTitleFromType(String type) {
    switch (type.toLowerCase()) {
      case 'joint_order_request':
        return '합동 주문 요청';
      case 'joint_order_update':
        return '합동 주문 상태 변경';
      case 'post_update':
        return '게시물 업데이트';
      case 'chat_message':
        return '새 메시지';
      case 'shared_cart_status':
        return '공동 장바구니 알림';
      case 'delivery_status':
        return '배달 상태 변경';
      case 'post_join':
        return '게시글 참여 알림';
      default:
        return '새 알림';
    }
  }

  static String _getMessageFromReference(String? referenceKey, String type) {
    if (referenceKey == null || referenceKey.isEmpty) {
      return '새로운 알림이 도착했습니다.';
    }

    // referenceKey 형식: "12:request" 또는 "8:status:matched"
    final parts = referenceKey.split(':');

    if (type.toLowerCase() == 'joint_order_request') {
      return '합동 주문 요청이 도착했습니다.';
    } else if (type.toLowerCase() == 'joint_order_update') {
      if (parts.length >= 3 && parts[2] == 'matched') {
        return '합동 주문 매칭이 완료되었습니다.';
      }
      return '합동 주문 상태가 변경되었습니다.';
    }

    return '새로운 알림이 도착했습니다.';
  }
}
