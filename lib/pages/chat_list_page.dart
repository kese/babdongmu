import 'dart:async';

import 'package:flutter/material.dart';
import '../models/chat_list_data.dart';
import '../models/chat_message_data.dart';
import '../services/api.dart';
import '../services/chat_socket_service.dart';
import '../services/notification_service.dart';
import '../services/app_notification_api.dart';
import '../widgets/notification_dropdown.dart';
import 'chat_room_page.dart';

/// 채팅방 목록을 표시하는 페이지
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  // 채팅방 목록
  List<ChatRoomList> chatRooms = [];
  bool isLoading = true;
  String? errorMessage;
  final Map<String, StreamSubscription<ChatMessage>> _roomSubscriptions = {};
  StreamSubscription<JointOrderStatusPayload>? _jointOrderStatusSubscription;

  // 알림 관련
  bool _showNotificationDropdown = false;
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _unreadCountSubscription;
  final OverlayPortalController _notificationOverlayController =
      OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _fetchChatRooms();
    _jointOrderStatusSubscription = NotificationService.jointOrderStatusUpdates
        .listen(_handleJointOrderStatusUpdate);
    unawaited(
      ChatSocketService.instance.ensureConnected().catchError((_) {
        debugPrint('채팅 실시간 연결 실패');
      }),
    );
  }

  /// 알림 시스템 초기화
  Future<void> _initializeNotifications() async {
    await AppNotificationApi.initialize();

    // 읽지 않은 알림 개수 스트림 구독
    _unreadCountSubscription = AppNotificationApi.unreadCountStream.listen((
      count,
    ) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    });

    // 초기 읽지 않은 알림 개수 설정
    setState(() {
      _unreadNotificationCount = AppNotificationApi.unreadCount;
    });
  }

  @override
  void dispose() {
    for (final entry in _roomSubscriptions.entries) {
      entry.value.cancel();
      ChatSocketService.instance.unsubscribeFromRoom(entry.key);
    }
    _roomSubscriptions.clear();
    _jointOrderStatusSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }

  /// 채팅방 목록 가져오기
  Future<void> _fetchChatRooms() async {
    await ApiService.fetchWithState<ChatRoomList>(
      apiCall: ChatApi.getChatRooms,
      setLoading: (loading) {
        if (mounted) setState(() => isLoading = loading);
      },
      onSuccess: (data) {
        if (mounted) {
          setState(() {
            chatRooms = data;
            errorMessage = null;
          });
          unawaited(_syncRoomSubscriptions());
        }
      },
      onError: (message) {
        if (mounted) setState(() => errorMessage = message);
      },
      fromJson: ChatRoomList.fromJson,
    );
  }

  Future<void> _syncRoomSubscriptions() async {
    if (!mounted) return;
    final currentIds = chatRooms.map((room) => room.id).toSet();

    final toRemove = _roomSubscriptions.keys
        .where((id) => !currentIds.contains(id))
        .toList(growable: false);
    for (final id in toRemove) {
      final sub = _roomSubscriptions.remove(id);
      await sub?.cancel();
      ChatSocketService.instance.unsubscribeFromRoom(id);
    }

    for (final room in chatRooms) {
      if (_roomSubscriptions.containsKey(room.id)) {
        continue;
      }
      try {
        final subscription = await ChatSocketService.instance.subscribeToRoom(
          roomId: room.id,
          onMessage: (message) => _handleRoomMessage(room.id, message),
        );
        _roomSubscriptions[room.id] = subscription;
      } catch (_) {
        debugPrint('채팅방 실시간 구독 실패');
      }
    }
  }

  void _handleRoomMessage(String roomId, ChatMessage message) {
    if (!mounted) return;
    final index = chatRooms.indexWhere((room) => room.id == roomId);
    if (index == -1) {
      _fetchChatRooms();
      return;
    }

    final updatedRoom = chatRooms[index].copyWith(
      lastMessage: message.message,
      lastMessageTime: _formatRelativeTime(message.timestamp),
      hasUnread: message.isMe ? chatRooms[index].hasUnread : true,
    );

    setState(() {
      final updatedList = List<ChatRoomList>.from(chatRooms);
      updatedList.removeAt(index);
      updatedList.insert(0, updatedRoom);
      chatRooms = updatedList;
    });
  }

  void _handleJointOrderStatusUpdate(JointOrderStatusPayload payload) {
    final status = payload.status.toLowerCase();
    if (status == 'matched') {
      unawaited(_handleJointOrderCompleted(payload.chatRoomId));
    }
  }

  Future<void> _handleJointOrderCompleted(String? chatRoomId) async {
    await _fetchChatRooms();
    if (!mounted) return;

    ChatRoomList? groupRoom;
    for (final room in chatRooms) {
      final isGroup = room.roomType == 'group';
      if (!isGroup) continue;
      if (chatRoomId == null || room.id == chatRoomId) {
        groupRoom = room;
        break;
      }
    }

    if (groupRoom != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('합동 주문 매칭이 완료되어 그룹 채팅방이 생성되었습니다.'),
          action: SnackBarAction(
            label: '바로 이동',
            onPressed: () => _openChatRoom(groupRoom!),
          ),
        ),
      );
    }
  }

  void _openChatRoom(ChatRoomList chatRoom) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatRoomPage(chatRoom: chatRoom)),
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 5) return '방금';
    if (diff.inMinutes < 1) return '${diff.inSeconds}초 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${timestamp.month}/${timestamp.day}';
  }

  /// 채팅방 위치 포맷팅 (storeName과 location 분리)
  Widget _buildLocationInfo(ChatRoomList chatRoom) {
    final hasStore = chatRoom.storeName.isNotEmpty;
    final hasLocation = chatRoom.location.isNotEmpty;

    if (!hasStore && !hasLocation) {
      return Text(
        '장소 정보 없음',
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      );
    }

    // 배달 장소 포맷팅: "POI / 상세주소" 형식
    final formattedLocation = hasLocation
        ? _formatDeliveryAddress(chatRoom.location)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 가게 이름 (음식점)
        if (hasStore)
          Row(
            children: [
              Icon(Icons.restaurant, size: 14, color: Colors.orange[700]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  chatRoom.storeName,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (hasStore && formattedLocation.isNotEmpty) const SizedBox(height: 4),
        // 배달 장소
        if (formattedLocation.isNotEmpty)
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.red[400]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  formattedLocation,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// 배달 장소 포맷팅: "POI / 상세내용" 형태로 표시
  /// 입력 형식: "POI (도로명주소 상세내용)" -> 출력: "POI / 상세내용"
  String _formatDeliveryAddress(String deliveryPlace) {
    final trimmed = deliveryPlace.trim();

    // 괄호가 있는 경우: "POI (도로명주소 상세내용)" 형식
    final parenOpen = trimmed.indexOf('(');
    final parenClose = trimmed.lastIndexOf(')');

    if (parenOpen > 0 && parenClose > parenOpen) {
      // POI 추출 (괄호 앞 부분)
      final poi = trimmed.substring(0, parenOpen).trim();

      // 괄호 안 내용 추출
      final insideParen = trimmed.substring(parenOpen + 1, parenClose).trim();

      // 괄호 안에서 상세내용 추출 (도로명주소 제외)
      final detail = _extractDetailFromAddress(insideParen);

      if (detail != null && detail.isNotEmpty) {
        return '$poi / $detail';
      }

      return poi;
    }

    // 괄호가 없는 경우 그대로 반환
    return trimmed;
  }

  /// 도로명주소에서 상세내용만 추출
  String? _extractDetailFromAddress(String address) {
    final parts = address.trim().split(' ');
    if (parts.isEmpty) return null;

    // 뒤에서부터 상세내용 찾기
    final detailParts = <String>[];

    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];

      // 도로명주소 구성요소 패턴
      final isAddressPart = RegExp(
        r'^(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주|충청북도|충청남도|전라북도|전라남도|경상북도|경상남도)'
        r'|.+(시|군|구)$'
        r'|.+(동|면|읍|리|로|길)$'
        r'|^\d+(-\d+)?$',
      ).hasMatch(part);

      if (isAddressPart) {
        break;
      }

      detailParts.insert(0, part);
    }

    if (detailParts.isEmpty) return null;

    return detailParts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (isLoading) {
      content = const Center(
        child: CircularProgressIndicator(color: Color(0xFF81C784)),
      );
    } else if (errorMessage != null) {
      content = _buildErrorState();
    } else if (chatRooms.isEmpty) {
      content = _buildEmptyState();
    } else {
      content = RefreshIndicator(
        onRefresh: _fetchChatRooms,
        color: const Color(0xFF81C784),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = chatRooms[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildChatRoomCard(chatRoom),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            SizedBox(
              width: 35,
              height: 35,
              child: const Icon(
                Icons.restaurant_menu,
                color: Color(0xFF81C784),
                size: 30,
              ),
            ),
            const SizedBox(width: 1),
            const Text(
              '밥동무',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          OverlayPortal(
            controller: _notificationOverlayController,
            overlayChildBuilder: (context) {
              return GestureDetector(
                onTap: () {
                  _notificationOverlayController.hide();
                  setState(() {
                    _showNotificationDropdown = false;
                  });
                },
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  children: [
                    Positioned(
                      top: kToolbarHeight + MediaQuery.of(context).padding.top,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {}, // 드롭다운 클릭 시 닫히지 않도록
                        child: NotificationDropdown(
                          onClose: () {
                            _notificationOverlayController.hide();
                            setState(() {
                              _showNotificationDropdown = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    if (_showNotificationDropdown) {
                      _notificationOverlayController.hide();
                    } else {
                      _notificationOverlayController.show();
                      // 알림 아이콘 클릭 시 읽지 않은 개수 초기화
                      AppNotificationApi.markAllAsRead();
                    }
                    setState(() {
                      _showNotificationDropdown = !_showNotificationDropdown;
                    });
                  },
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF81C784),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          _unreadNotificationCount > 9
                              ? '9+'
                              : _unreadNotificationCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "채팅방 목록" 제목
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Text(
              '채팅방 목록',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  /// 에러 상태 위젯
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(errorMessage!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchChatRooms,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81C784),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 채팅방이 없을 때 표시할 위젯
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '참여한 채팅방이 없습니다',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 채팅방 카드 위젯
  Widget _buildChatRoomCard(ChatRoomList chatRoom) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => _openChatRoom(chatRoom),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 첫 번째 줄: 제목과 상태 배지
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chatRoom.postTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (chatRoom.roomType == 'group') ...[
                    _buildGroupBadge(),
                  ] else if (chatRoom.postType.isNotEmpty) ...[
                    _buildStatusBadge(chatRoom.postType),
                  ],
                  const SizedBox(width: 8),
                  _buildMemberCountChip(chatRoom),
                ],
              ),
              const SizedBox(height: 8),
              // 두 번째 줄: 가게 이름 + 배달 장소
              _buildLocationInfo(chatRoom),
              const SizedBox(height: 12),
              // 세 번째 줄: 마지막 메시지와 시간
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chatRoom.lastMessage,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    chatRoom.lastMessageTime,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 상태에 따른 배경색 반환
  Color _getStatusColor(String status) {
    switch (status) {
      case '합동방':
        return const Color(0xFFE3F2FD);
      case '배달중':
        return const Color(0xFFE0F7F4);
      case '주문중':
        return const Color(0xFFFFF4E0);
      case '주문전':
        return const Color(0xFFE8F5E9);
      default:
        return Colors.grey[200]!;
    }
  }

  /// 상태에 따른 텍스트 색상 반환
  Color _getStatusTextColor(String status) {
    switch (status) {
      case '합동방':
        return const Color(0xFF1565C0);
      case '배달중':
        return const Color(0xFF00897B);
      case '주문중':
        return const Color(0xFFFF8F00);
      case '주문전':
        return const Color(0xFF81C784);
      default:
        return Colors.grey[700]!;
    }
  }

  Widget _buildGroupBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.groups_2, size: 12, color: Color(0xFF1565C0)),
          SizedBox(width: 4),
          Text(
            '합동방',
            style: TextStyle(
              color: Color(0xFF1565C0),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _getStatusTextColor(status),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMemberCountChip(ChatRoomList chatRoom) {
    final hasMax = chatRoom.maxPeople > 0;
    final label = hasMax
        ? '${chatRoom.currentPeople}/${chatRoom.maxPeople}'
        : '${chatRoom.currentPeople}명';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people, size: 12, color: Color(0xFF2E7D32)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
