
class ChatRoom {
  final int id;
  final String userName;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final String userProfileImage;

  ChatRoom({
    required this.id,
    required this.userName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.userProfileImage,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      userName: json['userName'],
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'],
      unreadCount: json['unreadCount'],
      userProfileImage: json['userProfileImage'],
    );
  }
}
