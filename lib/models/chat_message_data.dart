import 'dart:convert';

import 'package:delivery/models/shared_cart_data.dart';

/// 채팅방 내부에서 사용하는 메시지 하나의 데이터 모델
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isMe; // 내가 보낸 메시지인지 여부
  final String roomId;
  final String? type; // 메시지 타입 (일반: null, 영수증: 'receipt')
  final SharedCartSummary? cartSummary; // 영수증 데이터

  ChatMessage({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isMe,
    this.roomId = '',
    this.type,
    this.cartSummary,
  });

  // API 응답(JSON)을 ChatMessage 객체로 변환
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final messageId = json['id'] ?? json['message_id'] ?? json['messageId'];
    final senderId = json['sender_id'] ?? json['senderId'] ?? '';
    final senderName =
        json['sender_name'] ??
        json['senderName'] ??
        json['senderNickname'] ??
        '';
    final message =
        json['message'] ?? json['messageContent'] ?? json['content'] ?? '';
    final timestamp = _parseTimestamp(
      json['timestamp'] ?? json['sentAt'] ?? json['sent_at'],
    );
    final isMe = _parseBool(
      json['is_me'] ?? json['isMe'] ?? json['mine'] ?? json['mine_flag'],
    );
    final roomId = json['room_id'] ?? json['roomId'] ?? json['chatRoomId'];
    final resolvedId =
        messageId?.toString() ??
        '${senderId}_${message.hashCode}_${timestamp.millisecondsSinceEpoch}';
    final rawType = json['type'] ?? json['message_type'] ?? json['messageType'];
    final type = rawType?.toString().trim().toLowerCase();
    final cartSummaryData = _coerceMap(
      json['cart_summary'] ?? json['cartSummary'],
    );
    final cartSummary = cartSummaryData != null
        ? SharedCartSummary.fromJson(cartSummaryData)
        : null;

    return ChatMessage(
      id: resolvedId,
      senderId: senderId.toString(),
      senderName: senderName,
      message: message,
      timestamp: timestamp,
      isMe: isMe,
      roomId: roomId?.toString() ?? '',
      type: type,
      cartSummary: cartSummary,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? message,
    DateTime? timestamp,
    bool? isMe,
    String? roomId,
    String? type,
    SharedCartSummary? cartSummary,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      roomId: roomId ?? this.roomId,
      type: type ?? this.type,
      cartSummary: cartSummary ?? this.cartSummary,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      // 밀리초 or 초 단위 구분 (13자리면 ms)
      return value > 9999999999
          ? DateTime.fromMillisecondsSinceEpoch(value)
          : DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }

  // 안전한 불리언 변환 함수
  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'y') return true;
      return normalized == 'true' || normalized == '1';
    }
    return defaultValue;
  }

  static Map<String, dynamic>? _coerceMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = json.decode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, val) => MapEntry(key.toString(), val));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // 서버가 sender_id, timestamp 등을 요청할 경우 활성화
  /*
  Map<String, dynamic> toJson() => {
        'sender_id': senderId,
        'sender_name': senderName,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'is_me': isMe,
      };
  */
}
