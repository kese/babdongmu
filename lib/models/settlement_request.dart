class SettlementRequest {
  final String requestId;
  final String roomId;
  final String cartId;
  final String requesterId;
  final String requesterNickname;
  final int amount;
  final int? deliveryFeeShare;
  final String status;
  final String? memo;
  final String? decisionMemo;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;

  const SettlementRequest({
    required this.requestId,
    required this.roomId,
    required this.cartId,
    required this.requesterId,
    required this.requesterNickname,
    required this.amount,
    this.deliveryFeeShare,
    required this.status,
    this.memo,
    this.decisionMemo,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  SettlementRequest copyWith({
    String? status,
    String? decisionMemo,
    DateTime? processedAt,
    String? processedBy,
  }) {
    return SettlementRequest(
      requestId: requestId,
      roomId: roomId,
      cartId: cartId,
      requesterId: requesterId,
      requesterNickname: requesterNickname,
      amount: amount,
      deliveryFeeShare: deliveryFeeShare,
      status: status ?? this.status,
      memo: memo,
      decisionMemo: decisionMemo ?? this.decisionMemo,
      requestedAt: requestedAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
    );
  }

  factory SettlementRequest.fromJson(Map<String, dynamic> json) {
    final data = json;
    return SettlementRequest(
      requestId: _parseId(data['request_id'], data['requestId']),
      roomId: _parseId(data['room_id'], data['roomId']),
      cartId: _parseId(data['cart_id'], data['cartId']),
      requesterId: _parseId(data['requester_id'], data['requesterId']),
      requesterNickname:
          _parseString(data['requester_nickname'], data['requesterNickname']) ??
          '',
      amount: _parseInt(data['amount']),
      deliveryFeeShare: _parseNullableInt(
        data['delivery_fee_share'],
        data['deliveryFeeShare'],
      ),
      status: _parseString(data['status']) ?? 'PENDING',
      memo: _parseString(data['memo']),
      decisionMemo: _parseString(data['decision_memo'], data['decisionMemo']),
      requestedAt:
          _parseDate(
            data['requested_at'] ?? data['requestedAt'],
            fallbackNow: true,
          ) ??
          DateTime.now(),
      processedAt: _parseDate(data['processed_at'] ?? data['processedAt']),
      processedBy: _parseString(data['processed_by'], data['processedBy']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'roomId': roomId,
      'cartId': cartId,
      'requesterId': requesterId,
      'requesterNickname': requesterNickname,
      'amount': amount,
      'deliveryFeeShare': deliveryFeeShare,
      'status': status,
      'memo': memo,
      'decisionMemo': decisionMemo,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'processedBy': processedBy,
    };
  }

  static String _parseId(dynamic primary, [dynamic secondary]) {
    final raw = primary ?? secondary;
    if (raw == null) {
      return '';
    }
    return raw.toString();
  }

  static String? _parseString(dynamic primary, [dynamic secondary]) {
    final raw = primary ?? secondary;
    if (raw == null) {
      return null;
    }
    final value = raw.toString().trim();
    if (value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }

  static int _parseInt(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static int? _parseNullableInt(dynamic primary, [dynamic secondary]) {
    final raw = primary ?? secondary;
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value, {bool fallbackNow = false}) {
    if (value == null) {
      return fallbackNow ? DateTime.now() : null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      final millis = value > 9999999999 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return fallbackNow ? DateTime.now() : null;
  }
}
