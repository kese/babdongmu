import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_data.dart';
import '../services/app_notification_api.dart';
import '../pages/chat_room_page.dart';
import '../models/chat_list_data.dart';
import '../services/joint_order_api.dart';

/// 알림 드롭다운 위젯
class NotificationDropdown extends StatefulWidget {
  final VoidCallback onClose;

  const NotificationDropdown({super.key, required this.onClose});

  @override
  State<NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown> {
  List<NotificationData> _notifications = [];
  StreamSubscription<List<NotificationData>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  /// 알림 스트림 구독 (실시간 업데이트)
  void _subscribeToNotifications() {
    _notificationSubscription = AppNotificationApi.notificationsStream.listen((
      notifications,
    ) {
      if (mounted) {
        setState(() {
          _notifications = notifications;
        });
      }
    });
  }

  void _loadNotifications() {
    setState(() {
      _notifications = AppNotificationApi.notifications;
    });
  }

  /// 알림 클릭 처리
  Future<void> _handleNotificationTap(NotificationData notification) async {
    // 읽음 처리
    await AppNotificationApi.markAsRead(notification.id);

    // 모든 알림은 채팅방으로 이동
    final chatRoomId =
        notification.metadata?['chatRoomId'] ??
        notification.metadata?['roomId'];

    if (chatRoomId != null && mounted) {
      widget.onClose();
      await _navigateToChatRoom(chatRoomId);
    }

    _loadNotifications();
  }

  /// 채팅방으로 이동
  Future<void> _navigateToChatRoom(String chatRoomId) async {
    try {
      final result = await JointOrderApi.getJointChatRoomInfo(chatRoomId);

      if (result['success'] == true && mounted) {
        final chatRoomData = result['data'];
        final chatRoom = ChatRoomList.fromJson(chatRoomData);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomPage(chatRoom: chatRoom),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('채팅방을 불러올 수 없습니다.')));
      }
    }
  }

  /// 모든 알림 읽음 처리
  Future<void> _markAllAsRead() async {
    await AppNotificationApi.markAllAsRead();
    _loadNotifications();
  }

  /// 시간 포맷팅
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM/dd').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      constraints: const BoxConstraints(maxHeight: 350),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '알림',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_notifications.any((n) => !n.isRead))
                  TextButton(
                    onPressed: _markAllAsRead,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '모두 읽음',
                      style: TextStyle(fontSize: 13, color: Color(0xFF81C784)),
                    ),
                  ),
              ],
            ),
          ),

          // 알림 목록
          Flexible(
            child: _notifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationItem(_notifications[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            '알림이 없습니다',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 알림 아이템 위젯
  Widget _buildNotificationItem(NotificationData notification) {
    return Material(
      color: notification.isRead ? Colors.white : const Color(0xFFF1F8F4),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 읽지 않음 표시
              if (!notification.isRead)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF81C784),
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 16),

              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: notification.isRead
                            ? FontWeight.normal
                            : FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 알림 타입별 아이콘
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'chat_join':
        return Icons.chat;
      case 'joint_order_request':
        return Icons.group_add;
      case 'joint_order_matched':
        return Icons.check_circle;
      case 'joint_order_status':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }
}
