/// 서버로부터 받아온 '같이 먹을 친구 구하기' 게시글 하나의 데이터 구조만 정의한 데이터 모델
/// API 응답으로 받은 JSON 데이터를 Dart 객체로 변환하여 사용
library;

class FriendPost {
  final String id; // 게시글 고유 id
  final String userName; // 닉네임
  final String? userProfileImage; // 사용자 프로필 이미지 URL
  final String date; // 게시글 작성 날짜
  final String title; // 제목
  final String storeName; // 가게 이름
  final String meetingPlace; // 만날 장소
  final int currentPeople; // 현재 참여 중인 인원 수
  final int maxPeople; // 최대 모집 인원
  final bool isRecruiting; // 모집중인지 여부(true: 모집중, false: 모집 완료)
  final DateTime deadline; // 마감 시간
  final double? meetingLatitude; // 만남장소 위도
  final double? meetingLongitude; // 만남장소 경도
  final String? details; // 상세 내용 (선택)

  FriendPost({
    required this.id,
    required this.userName,
    this.userProfileImage,
    required this.date,
    required this.title,
    required this.storeName,
    required this.meetingPlace,
    required this.currentPeople,
    required this.maxPeople,
    required this.isRecruiting,
    required this.deadline,
    this.meetingLatitude,
    this.meetingLongitude,
    this.details,
  });

  // JSON 데이터를 FriendPost 객체로 변환
  factory FriendPost.fromJson(Map<String, dynamic> json) {
    final meetDetail = _asMap(json['meetDetail']);
    final participantsList =
        _asList(
          json['participants'] ??
              json['participantList'] ??
              json['members'] ??
              json['participantUsers'] ??
              meetDetail?['participants'],
        ) ??
        _asList(json['currentUsers']);

    final maxParticipants = _firstInt([
      json['max_people'],
      json['maxPeople'],
      json['max_participants'],
      json['maxParticipants'],
      json['maxParticipant'],
      json['participantLimit'],
      json['capacity'],
      json['maxMemberCount'],
      meetDetail?['maxParticipants'],
      meetDetail?['maxPeople'],
      meetDetail?['participantLimit'],
    ], defaultValue: participantsList?.length ?? 0);

    final currentParticipants = _firstInt([
      json['current_people'],
      json['currentPeople'],
      json['current_participants'],
      json['currentParticipants'],
      json['currentMemberCount'],
      json['joinedCount'],
      json['participantCount'],
      json['currentMembers'],
      meetDetail?['currentParticipants'],
    ], defaultValue: participantsList?.length ?? 0);

    bool? recruitingFromJson;
    if (json.containsKey('is_recruiting') || json.containsKey('isRecruiting')) {
      recruitingFromJson = _parseBool(
        json['is_recruiting'] ?? json['isRecruiting'],
      );
    }

    bool? recruitingFromStatus;
    final statusValue = _pickString([
      json['status'],
      json['postStatus'],
      json['post_status'],
      meetDetail?['status'],
    ]);
    if (statusValue != null) {
      final normalized = statusValue.toUpperCase();
      if ({
        'OPEN',
        'ACTIVE',
        'RECRUITING',
        'IN_PROGRESS',
      }.contains(normalized)) {
        recruitingFromStatus = true;
      } else if ({
        'CLOSED',
        'FINISHED',
        'COMPLETED',
        'COMPLETE',
        'FULL',
        'ENDED',
        'INACTIVE',
      }.contains(normalized)) {
        recruitingFromStatus = false;
      }
    }

    bool? recruitmentClosed;
    if (json.containsKey('recruitmentClosed') ||
        json.containsKey('recruitment_closed')) {
      recruitmentClosed = _parseBool(
        json['recruitmentClosed'] ?? json['recruitment_closed'],
      );
    }

    final inferredCurrent = currentParticipants > 0
        ? currentParticipants
        : (participantsList?.length ?? currentParticipants);

    int inferredMax = maxParticipants;
    if (inferredMax == 0 && participantsList != null) {
      inferredMax = participantsList.length;
    }
    if (inferredMax > 0 && inferredCurrent > inferredMax) {
      inferredMax = inferredCurrent;
    }

    bool computedIsRecruiting =
        inferredMax == 0 || inferredCurrent < inferredMax;
    if (recruitingFromJson == false ||
        recruitingFromStatus == false ||
        recruitmentClosed == true) {
      computedIsRecruiting = false;
    }

    final meetingTime =
        json['deadline'] ??
        json['meetingTime'] ??
        json['deadlineAt'] ??
        json['meeting_time'] ??
        meetDetail?['meetingTime'];

    final userName =
        _pickString([
          json['user_name'],
          json['userName'],
          json['writerName'],
          json['authorNickname'],
          json['authorName'],
          json['author'],
          json['nickname'],
        ]) ??
        '익명';

    // 사용자 프로필 이미지 파싱
    final userProfileImage = _pickString([
      json['authorProfileImage'],
      json['author_profile_image'],
      json['userProfileImage'],
      json['user_profile_image'],
      json['profileImage'],
      json['profile_image'],
      json['writerProfileImage'],
      meetDetail?['authorProfileImage'],
      meetDetail?['ownerProfileImage'],
    ]);

    final date = _formatDisplayDate(
      _pickString([json['date'], json['createdAt'], json['created_at']]),
    );

    final parsedId = _parseId(json);

    return FriendPost(
      id: parsedId,
      userName: userName,
      userProfileImage: userProfileImage,
      date: date,
      title: json['title'] ?? json['postTitle'] ?? '',
      storeName:
          _pickString([
            json['store_name'],
            json['storeName'],
            meetDetail?['storeName'],
            json['restaurantName'],
            json['restaurant_name'],
          ]) ??
          '',
      meetingPlace:
          _pickString([
            json['meeting_place'],
            json['meetingPlace'],
            json['deliveryPlace'],
            meetDetail?['meetingPlace'],
          ]) ??
          '',
      currentPeople: inferredCurrent,
      maxPeople: inferredMax,
      isRecruiting: computedIsRecruiting,
      deadline: _parseDateTime(meetingTime) ?? DateTime.now(),
      meetingLatitude: _parseDouble(
        json['meeting_latitude'] ??
            json['meetingLatitude'] ??
            json['location_latitude'] ??
            json['locationLatitude'] ??
            meetDetail?['meetingLatitude'] ??
            meetDetail?['latitude'],
      ),
      meetingLongitude: _parseDouble(
        json['meeting_longitude'] ??
            json['meetingLongitude'] ??
            json['location_longitude'] ??
            json['locationLongitude'] ??
            meetDetail?['meetingLongitude'] ??
            meetDetail?['longitude'],
      ),
      details: _pickString([
        json['details'],
        json['description'],
        json['content'],
        meetDetail?['details'],
      ]),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
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

  static String _parseId(Map<String, dynamic> json) {
    final candidates = [
      json['id'],
      json['postId'],
      json['post_id'],
      json['postID'],
    ];

    for (final candidate in candidates) {
      final normalized = _normalizeNumericId(candidate);
      if (normalized != null) {
        return normalized;
      }
    }

    return 'unknown_id';
  }

  static String? _normalizeNumericId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value.toString();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final numeric = int.tryParse(trimmed);
      if (numeric != null) {
        return numeric.toString();
      }
      return null;
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

  // 안전한 정수 변환 함수(응답 값이 어떤 타입으로 와도 정수로 변환)
  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // 안전한 불리언 변환 함수(응답 값이 어떤 타입으로 와도 안전하게 참/거짓으로 변환)
  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' ||
          value == '1'; // 대소문자 구분 없이 true 또는 1 일때 true로 인정
    }
    return defaultValue;
  }

  static String? _pickString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  static String _formatDisplayDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.month}월 ${parsed.day}일';
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      if (raw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
      final replaced = trimmed.replaceAll(' ', 'T');
      return DateTime.tryParse(replaced);
    }
    return null;
  }
}
