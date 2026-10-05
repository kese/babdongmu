/// 합동 주문 매칭 관련 데이터 모델
library;

/// 매칭 가능한 게시글 정보
class MatchablePost {
  final String id;
  final String title;
  final String storeName;
  final String deliveryPlace;
  final String authorName;
  final int currentPeople;
  final int maxPeople;
  final DateTime deadline;
  bool isSelected; // 체크박스 선택 여부

  MatchablePost({
    required this.id,
    required this.title,
    required this.storeName,
    required this.deliveryPlace,
    required this.authorName,
    required this.currentPeople,
    required this.maxPeople,
    required this.deadline,
    this.isSelected = false,
  });

  factory MatchablePost.fromJson(Map<String, dynamic> json) {
    return MatchablePost(
      id: json['id']?.toString() ?? json['postId']?.toString() ?? '',
      title: json['title'] ?? json['postTitle'] ?? '',
      storeName: json['store_name'] ?? json['storeName'] ?? json['restaurantName'] ?? '',
      deliveryPlace: json['delivery_place'] ?? json['deliveryPlace'] ?? json['meetingPlace'] ?? '',
      authorName: json['user_name'] ?? json['userName'] ?? json['authorName'] ?? '익명',
      currentPeople: _parseInt(json['current_people'] ?? json['currentPeople']),
      maxPeople: _parseInt(json['max_people'] ?? json['maxPeople']),
      deadline: _parseDateTime(json['deadline'] ?? json['meetingTime']) ?? DateTime.now(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// 합동 주문 요청 정보
class JointOrderRequest {
  final String requesterId; // 요청자 ID
  final String requesterName; // 요청자 닉네임
  final String requesterPostId; // 요청자의 게시글 ID
  final List<String> targetPostIds; // 요청 대상 게시글 ID 목록
  final DateTime requestTime; // 요청 시간
  final String status; // 요청 상태: pending, accepted, rejected, expired

  JointOrderRequest({
    required this.requesterId,
    required this.requesterName,
    required this.requesterPostId,
    required this.targetPostIds,
    required this.requestTime,
    this.status = 'pending',
  });

  factory JointOrderRequest.fromJson(Map<String, dynamic> json) {
    return JointOrderRequest(
      requesterId: json['requester_id'] ?? json['requesterId'] ?? '',
      requesterName: json['requester_name'] ?? json['requesterName'] ?? '익명',
      requesterPostId: json['requester_post_id'] ?? json['requesterPostId'] ?? '',
      targetPostIds: List<String>.from(json['target_post_ids'] ?? json['targetPostIds'] ?? []),
      requestTime: DateTime.tryParse(json['request_time'] ?? json['requestTime'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_post_id': requesterPostId,
      'target_post_ids': targetPostIds,
      'request_time': requestTime.toIso8601String(),
      'status': status,
    };
  }
}

/// 합동 주문 요청 응답 정보
class JointOrderResponse {
  final String requestId; // 요청 ID
  final String postId; // 응답하는 게시글 ID
  final String responderId; // 응답자 ID
  final String responderName; // 응답자 닉네임
  final bool accepted; // 수락 여부
  final DateTime responseTime; // 응답 시간

  JointOrderResponse({
    required this.requestId,
    required this.postId,
    required this.responderId,
    required this.responderName,
    required this.accepted,
    required this.responseTime,
  });

  factory JointOrderResponse.fromJson(Map<String, dynamic> json) {
    return JointOrderResponse(
      requestId: json['request_id'] ?? json['requestId'] ?? '',
      postId: json['post_id'] ?? json['postId'] ?? '',
      responderId: json['responder_id'] ?? json['responderId'] ?? '',
      responderName: json['responder_name'] ?? json['responderName'] ?? '익명',
      accepted: json['accepted'] ?? false,
      responseTime: DateTime.tryParse(json['response_time'] ?? json['responseTime'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'post_id': postId,
      'responder_id': responderId,
      'responder_name': responderName,
      'accepted': accepted,
      'response_time': responseTime.toIso8601String(),
    };
  }
}
