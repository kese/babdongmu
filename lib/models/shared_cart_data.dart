/// 공용 장바구니 관련 모델
library;

/// 공용 장바구니 메뉴 아이템
class CartMenuItem {
  final String id;
  final String name;
  final int price;
  final String userId;
  final String userNickname;

  const CartMenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.userId,
    required this.userNickname,
  });

  factory CartMenuItem.fromJson(Map<String, dynamic> json) {
    return CartMenuItem(
      id: _coerceString(json['id'] ?? json['item_id']),
      name: _coerceString(json['name']),
      price: _coerceInt(json['price']),
      userId: _coerceString(json['user_id'] ?? json['userId']),
      userNickname: _coerceString(
        json['user_nickname'] ?? json['userNickname'],
      ),
    );
  }

  CartMenuItem copyWith({
    String? id,
    String? name,
    int? price,
    String? userId,
    String? userNickname,
  }) {
    return CartMenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      userId: userId ?? this.userId,
      userNickname: userNickname ?? this.userNickname,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'user_id': userId,
      'user_nickname': userNickname,
    };
  }
}

/// 공용 장바구니 상태
class SharedCart {
  final String id;
  final String roomId;
  final bool isActive;
  final bool isCompleted;
  final List<CartMenuItem> items;
  final String hostId;
  final String hostNickname;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final int? _totalMenuPrice;
  final int? _totalPrice;
  final int? _deliveryFee;

  const SharedCart({
    required this.id,
    required this.roomId,
    required this.isActive,
    required this.items,
    required this.hostId,
    this.hostNickname = '',
    this.isCompleted = false,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    int? totalMenuPrice,
    int? totalPrice,
    int? deliveryFee,
  }) : _totalMenuPrice = totalMenuPrice,
       _totalPrice = totalPrice,
       _deliveryFee = deliveryFee;

  int get totalMenuPrice =>
      _totalMenuPrice ?? items.fold(0, (sum, item) => sum + item.price);

  int get deliveryFee => _deliveryFee ?? 0;

  int get totalPrice => _totalPrice ?? (totalMenuPrice + deliveryFee);

  factory SharedCart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <CartMenuItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(CartMenuItem.fromJson(entry));
        } else if (entry is Map) {
          final normalized = entry.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          items.add(CartMenuItem.fromJson(normalized));
        }
      }
    }

    final statusValue = _coerceString(json['status']);
    const completedTokens = {
      'completed',
      'finalized',
      'done',
      'closed',
      'settled',
      'finished',
    };
    const activeTokens = {
      'active',
      'ordering',
      'in_progress',
      'ordering_started',
      'order_started',
      'ordering_ready',
      'order_ready',
      'ordering_open',
      'order_open',
      'started',
      'start',
      'open',
      'ready',
      'progress',
    };

    final statusToken = statusValue.toLowerCase();
    final isCompleted =
        _coerceBool(
          json['is_completed'] ?? json['completed'] ?? json['isCompleted'],
        ) ||
        completedTokens.contains(statusToken);

    final rawActiveFlag =
        json['is_active'] ?? json['isActive'] ?? json['active'];
    final bool? explicitActive = _coerceOptionalBool([rawActiveFlag]);
    final derivedActive = activeTokens.contains(statusToken);
    final isActive = explicitActive ?? derivedActive;

    return SharedCart(
      id: _coerceString(json['id'] ?? json['cart_id'] ?? json['cartId']),
      roomId: _coerceString(json['room_id'] ?? json['roomId']),
      isActive: isActive,
      isCompleted: isCompleted,
      items: items,
      hostId: _coerceString(json['host_id'] ?? json['hostId']),
      hostNickname: _coerceString(
        json['host_nickname'] ?? json['hostNickname'] ?? json['host_name'],
      ),
      createdAt: _coerceDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _coerceDateTime(json['updated_at'] ?? json['updatedAt']),
      completedAt: _coerceDateTime(
        json['completed_at'] ?? json['completedAt'],
        fallback: isCompleted,
      ),
      totalMenuPrice: _coerceNullableInt(
        json['total_menu_price'] ?? json['menu_total'],
      ),
      totalPrice: _coerceNullableInt(json['total_price'] ?? json['totalPrice']),
      deliveryFee: _coerceNullableInt(
        json['delivery_fee'] ?? json['deliveryFee'],
      ),
    );
  }

  SharedCart copyWith({
    String? id,
    String? roomId,
    bool? isActive,
    bool? isCompleted,
    List<CartMenuItem>? items,
    String? hostId,
    String? hostNickname,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    int? totalMenuPrice,
    int? totalPrice,
    int? deliveryFee,
  }) {
    return SharedCart(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      items: items ?? this.items,
      hostId: hostId ?? this.hostId,
      hostNickname: hostNickname ?? this.hostNickname,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      totalMenuPrice: totalMenuPrice ?? _totalMenuPrice,
      totalPrice: totalPrice ?? _totalPrice,
      deliveryFee: deliveryFee ?? _deliveryFee,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'isActive': isActive,
      'isCompleted': isCompleted,
      'items': items.map((item) => item.toJson()).toList(),
      'hostId': hostId,
      'hostNickname': hostNickname,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'totalMenuPrice': _totalMenuPrice,
      'totalPrice': _totalPrice,
      'deliveryFee': _deliveryFee,
    };
  }
}

/// 공유된 영수증 요약 정보
class SharedCartSummary {
  final String cartId;
  final List<CartMenuItem> items;
  final int totalMenuPrice;
  final int totalPrice;
  final int deliveryFee;
  final String hostId;
  final String hostNickname;
  final DateTime createdAt;
  final DateTime? finalizedAt;
  final String receiptStatus;
  final int? deliveryFeePerPerson;
  final String? receiptId;
  final String? memo;

  const SharedCartSummary({
    required this.cartId,
    required this.items,
    required this.totalMenuPrice,
    required this.totalPrice,
    required this.deliveryFee,
    required this.hostId,
    required this.hostNickname,
    required this.createdAt,
    this.finalizedAt,
    this.receiptStatus = 'pending',
    this.deliveryFeePerPerson,
    this.receiptId,
    this.memo,
  });

  bool get isFinalized => receiptStatus.toLowerCase() == 'finalized';

  factory SharedCartSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <CartMenuItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(CartMenuItem.fromJson(entry));
        } else if (entry is Map) {
          final normalized = entry.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          items.add(CartMenuItem.fromJson(normalized));
        }
      }
    }

    return SharedCartSummary(
      cartId: _coerceString(json['cart_id'] ?? json['cartId'] ?? json['id']),
      items: items,
      totalMenuPrice: _coerceInt(
        json['total_menu_price'] ?? json['menu_total'] ?? json['items_total'],
      ),
      totalPrice: _coerceInt(json['total_price'] ?? json['totalPrice']),
      deliveryFee: _coerceInt(json['delivery_fee'] ?? json['deliveryFee']),
      hostId: _coerceString(json['host_id'] ?? json['hostId']),
      hostNickname: _coerceString(
        json['host_nickname'] ?? json['hostNickname'] ?? json['host_name'],
      ),
      createdAt:
          _coerceDateTime(
            json['created_at'] ?? json['createdAt'],
            fallback: true,
          ) ??
          DateTime.now(),
      finalizedAt: _coerceDateTime(json['finalized_at'] ?? json['finalizedAt']),
      receiptStatus: _parseReceiptStatus(
        json['receipt_status'] ?? json['status'],
      ),
      deliveryFeePerPerson: _coerceNullableInt(
        json['delivery_fee_per_person'] ?? json['deliveryFeePerPerson'],
      ),
      receiptId: _coerceOptionalString([
        json['receipt_id'],
        json['receiptId'],
        json['id'],
      ]),
      memo: _coerceOptionalString([json['memo'], json['note']]),
    );
  }

  SharedCartSummary copyWith({
    String? cartId,
    List<CartMenuItem>? items,
    int? totalMenuPrice,
    int? totalPrice,
    int? deliveryFee,
    String? hostId,
    String? hostNickname,
    DateTime? createdAt,
    DateTime? finalizedAt,
    String? receiptStatus,
    int? deliveryFeePerPerson,
    String? receiptId,
    String? memo,
  }) {
    return SharedCartSummary(
      cartId: cartId ?? this.cartId,
      items: items ?? this.items,
      totalMenuPrice: totalMenuPrice ?? this.totalMenuPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      hostId: hostId ?? this.hostId,
      hostNickname: hostNickname ?? this.hostNickname,
      createdAt: createdAt ?? this.createdAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      receiptStatus: receiptStatus ?? this.receiptStatus,
      deliveryFeePerPerson: deliveryFeePerPerson ?? this.deliveryFeePerPerson,
      receiptId: receiptId ?? this.receiptId,
      memo: memo ?? this.memo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cartId': cartId,
      'items': items.map((item) => item.toJson()).toList(),
      'totalMenuPrice': totalMenuPrice,
      'totalPrice': totalPrice,
      'deliveryFee': deliveryFee,
      'hostId': hostId,
      'hostNickname': hostNickname,
      'createdAt': createdAt.toIso8601String(),
      'finalizedAt': finalizedAt?.toIso8601String(),
      'receiptStatus': receiptStatus,
      'deliveryFeePerPerson': deliveryFeePerPerson,
      'receiptId': receiptId,
      'memo': memo,
    };
  }
}

/// 확정된 참여자 상태 정보
class TargetParticipantStatus {
  final String userId;
  final String nickname;
  final bool hasConfirmedReception;
  final bool hasReportedIssue;
  final String paymentStatus;
  final bool hasPaid;
  final bool isHost;
  final bool hasAcceptedDeliveryGuide;

  const TargetParticipantStatus({
    required this.userId,
    required this.nickname,
    this.hasConfirmedReception = false,
    this.hasReportedIssue = false,
    this.paymentStatus = 'pending',
    this.hasPaid = false,
    this.isHost = false,
    this.hasAcceptedDeliveryGuide = false,
  });

  factory TargetParticipantStatus.fromJson(Map<String, dynamic> json) {
    final paymentStatus = _parsePaymentStatus(json);
    final parsedHasPaid = _coerceOptionalBool([
      json['has_paid'],
      json['hasPaid'],
      json['is_paid'],
      json['paid'],
      json['payment_completed'],
    ]);
    final roleRaw = json['role'] ?? json['user_role'] ?? json['userRole'];
    final roleToken = roleRaw == null
        ? ''
        : roleRaw.toString().trim().toLowerCase();
    final explicitHostFlag = _coerceBool(json['is_host'] ?? json['isHost']);
    final isHostFromRole =
        roleToken == 'host' || roleToken == 'leader' || roleToken == 'creator';
    final acceptedGuide =
        _coerceOptionalBool([
          json['has_accepted_delivery_guide'],
          json['hasAcceptedDeliveryGuide'],
          json['accepted_delivery_guide'],
          json['acceptedGuide'],
        ]) ??
        false;

    return TargetParticipantStatus(
      userId: _coerceString(json['user_id'] ?? json['userId']),
      nickname: _coerceString(json['nickname'] ?? json['userNickname']),
      hasConfirmedReception: _coerceBool(
        json['has_confirmed_reception'] ?? json['hasConfirmedReception'],
      ),
      hasReportedIssue: _coerceBool(
        json['has_reported_issue'] ?? json['hasReportedIssue'],
      ),
      paymentStatus: paymentStatus,
      hasPaid: parsedHasPaid ?? _isPaidStatus(paymentStatus),
      isHost: explicitHostFlag || isHostFromRole,
      hasAcceptedDeliveryGuide: acceptedGuide,
    );
  }

  TargetParticipantStatus copyWith({
    bool? hasConfirmedReception,
    bool? hasReportedIssue,
    String? paymentStatus,
    bool? hasPaid,
    bool? isHost,
    bool? hasAcceptedDeliveryGuide,
  }) {
    return TargetParticipantStatus(
      userId: userId,
      nickname: nickname,
      hasConfirmedReception:
          hasConfirmedReception ?? this.hasConfirmedReception,
      hasReportedIssue: hasReportedIssue ?? this.hasReportedIssue,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      hasPaid: hasPaid ?? this.hasPaid,
      isHost: isHost ?? this.isHost,
      hasAcceptedDeliveryGuide:
          hasAcceptedDeliveryGuide ?? this.hasAcceptedDeliveryGuide,
    );
  }

  TargetParticipantStatus mergeWith(TargetParticipantStatus other) {
    final normalizedId = userId.trim();
    final incomingId = other.userId.trim();
    assert(
      normalizedId == incomingId,
      'mergeWith는 동일한 사용자 ID에 대해서만 호출할 수 있습니다.',
    );

    final resolvedPaymentStatus = _selectPreferredStatus(
      paymentStatus,
      other.paymentStatus,
    );

    return TargetParticipantStatus(
      userId: userId,
      nickname: other.nickname.isNotEmpty ? other.nickname : nickname,
      hasConfirmedReception:
          hasConfirmedReception || other.hasConfirmedReception,
      hasReportedIssue: hasReportedIssue || other.hasReportedIssue,
      paymentStatus: resolvedPaymentStatus,
      hasPaid: hasPaid || other.hasPaid || _isPaidStatus(resolvedPaymentStatus),
      isHost: isHost || other.isHost,
      hasAcceptedDeliveryGuide:
          hasAcceptedDeliveryGuide || other.hasAcceptedDeliveryGuide,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TargetParticipantStatus &&
        other.userId == userId &&
        other.nickname == nickname &&
        other.hasConfirmedReception == hasConfirmedReception &&
        other.hasReportedIssue == hasReportedIssue &&
        other.paymentStatus == paymentStatus &&
        other.hasPaid == hasPaid &&
        other.isHost == isHost &&
        other.hasAcceptedDeliveryGuide == hasAcceptedDeliveryGuide;
  }

  @override
  int get hashCode => Object.hash(
    userId,
    nickname,
    hasConfirmedReception,
    hasReportedIssue,
    paymentStatus,
    hasPaid,
    isHost,
    hasAcceptedDeliveryGuide,
  );
}

String _coerceString(dynamic value) {
  if (value == null) return '';
  final raw = value.toString().trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null') {
    return '';
  }
  return raw;
}

String? _coerceOptionalString(List<dynamic> candidates) {
  for (final candidate in candidates) {
    if (candidate == null) continue;
    final value = _coerceString(candidate);
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

int _coerceInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

int? _coerceNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return int.tryParse(trimmed);
  }
  return null;
}

bool _coerceBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'null') {
      return false;
    }
    return const {
      'true',
      '1',
      'yes',
      'y',
      'on',
      'completed',
      'finalized',
      'done',
      'active',
      'enabled',
    }.contains(normalized);
  }
  return false;
}

bool? _coerceOptionalBool(List<dynamic> candidates) {
  for (final candidate in candidates) {
    if (candidate == null) continue;
    if (candidate is bool) return candidate;
    if (candidate is num) return candidate != 0;
    if (candidate is String) {
      final normalized = candidate.trim().toLowerCase();
      if (normalized.isEmpty || normalized == 'null') {
        continue;
      }
      if (const {'true', '1', 'yes', 'y', 'on'}.contains(normalized)) {
        return true;
      }
      if (const {'false', '0', 'no', 'n', 'off'}.contains(normalized)) {
        return false;
      }
    }
  }
  return null;
}

DateTime? _coerceDateTime(dynamic value, {bool fallback = false}) {
  if (value == null) {
    return fallback ? DateTime.now() : null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    final millis = value > 9999999999 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return fallback ? DateTime.now() : null;
}

String _parseReceiptStatus(dynamic value) {
  if (value == null) {
    return 'pending';
  }
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'null') {
    return 'pending';
  }
  return normalized;
}

String _parsePaymentStatus(Map<String, dynamic> json) {
  final candidates = [
    json['payment_status'],
    json['paymentStatus'],
    json['settlement_status'],
    json['settlementStatus'],
    json['escrow_status'],
    json['escrowStatus'],
  ];
  for (final candidate in candidates) {
    if (candidate == null) continue;
    final value = candidate.toString().trim();
    if (value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }
  return 'pending';
}

bool _isPaidStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'paid' ||
      normalized == 'approved' ||
      normalized == 'completed' ||
      normalized == 'confirmed';
}

int _statusPriority(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'null') {
    return 0;
  }
  if (_isPaidStatus(normalized)) {
    return 100;
  }
  const priorityMap = {
    'pending': 1,
    'requested': 2,
    'waiting': 2,
    'pending_approval': 2,
    'processing': 3,
    'in_progress': 3,
    'approved': 80,
    'confirmed': 90,
    'paid': 100,
    'completed': 100,
    'settled': 100,
    'success': 100,
  };
  return priorityMap[normalized] ?? 1;
}

String _selectPreferredStatus(String current, String incoming) {
  final currentScore = _statusPriority(current);
  final incomingScore = _statusPriority(incoming);
  if (incomingScore > currentScore) {
    return incoming;
  }
  if (incomingScore == 0 && currentScore > 0) {
    return current;
  }
  if (incomingScore == currentScore) {
    return incoming.trim().isNotEmpty ? incoming : current;
  }
  return current;
}
