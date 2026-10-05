/// 사용자 정보 모델
class User {
  final String name;
  final String email;
  final String phone;
  final String nickname;
  final String? address;
  final String? account;
  final String? profileImage;

  User({
    required this.name,
    required this.email,
    required this.phone,
    required this.nickname,
    this.address,
    this.account,
    this.profileImage,
  });

  // JSON -> User 객체 변환
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      nickname: json['nickname'] ?? '',
      address: json['address'],
      account: json['account'],
      // 서버 응답 형식에 따라 profileImage 또는 profile_image 모두 지원
      profileImage: json['profileImage'] ?? json['profile_image'],
    );
  }

  // User 객체 -> JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'nickname': nickname,
      'address': address,
      'account': account,
      'profile_image': profileImage,
    };
  }
}

/// 포인트 정보 모델
class UserPoints {
  final int points;

  UserPoints({required this.points});

  factory UserPoints.fromJson(Map<String, dynamic> json) {
    return UserPoints(points: json['points'] ?? 0);
  }

  Map<String, dynamic> toJson() {
    return {'points': points};
  }
}
