import '../models/notification_data.dart';

/// 더미 알림 데이터
class DummyNotificationData {
  static List<NotificationData> get sampleNotifications => [
        // 합동 주문 매칭 성공 알림
        NotificationData(
          id: 'notif_1',
          type: 'joint_order_update',
          title: '합동 주문 매칭 성공',
          message: '모든 참여자가 수락해 새로운 채팅방이 개설되었습니다.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isRead: false,
          metadata: {
            'chatRoomId': 'room_1',
            'requestId': 'req_123',
            'status': 'matched',
          },
        ),
        
        // 합동 주문 요청 알림
        NotificationData(
          id: 'notif_2',
          type: 'joint_order_request',
          title: '새 합동 주문 요청',
          message: '테스트 사용자 B님이 예시 매장 (공용 수령 장소) 합동 주문을 요청했습니다.',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          isRead: false,
          metadata: {
            'requestId': 'req_456',
            'requesterId': 'user_123',
            'requesterName': '테스트 사용자 B',
            'storeName': '예시 매장',
            'deliveryPlace': '공용 수령 장소',
          },
        ),
        
        // 합동 주문 수락 알림
        NotificationData(
          id: 'notif_3',
          type: 'joint_order_update',
          title: '합동 주문 상태 변경',
          message: '요청이 수락되었습니다.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: true,
          metadata: {
            'chatRoomId': 'room_2',
            'requestId': 'req_789',
            'status': 'accepted',
          },
        ),
        
        // 게시물 상태 변경 알림
        NotificationData(
          id: 'notif_4',
          type: 'post_update',
          title: '게시물 상태 변경',
          message: '작성하신 게시물의 상태가 변경되었습니다.',
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          isRead: true,
          metadata: {
            'postId': 'post_123',
          },
        ),
        
        // 합동 주문 거절 알림
        NotificationData(
          id: 'notif_5',
          type: 'joint_order_update',
          title: '합동 주문 상태 변경',
          message: '요청이 거절되었습니다.',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
          metadata: {
            'requestId': 'req_999',
            'status': 'rejected',
          },
        ),
        
        // 합동 주문 타임아웃 알림
        NotificationData(
          id: 'notif_6',
          type: 'joint_order_update',
          title: '합동 주문 상태 변경',
          message: '응답 지연으로 요청이 만료되었습니다.',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
          metadata: {
            'requestId': 'req_888',
            'status': 'timeout',
          },
        ),
      ];
}
