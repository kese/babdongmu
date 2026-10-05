import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../widgets/delivery_tab.dart';
import '../widgets/friend_tab.dart';
import '../widgets/notification_dropdown.dart';
import '../models/chat_list_data.dart';
import 'chat_list_page.dart';
import 'chat_room_page.dart';
import 'joint_order_page.dart';
import 'map_page.dart';
import 'my_page.dart';
import '../services/joint_order_api.dart';
import '../services/notification_service.dart';
import '../services/app_notification_api.dart';
import '../utils/logging.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

// SingleTickerProviderStateMixin: TabController의 애니메이션 부드럽게 처리하기 위한 Mixin
class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // '함께 배달'과 '친구 구하기' 탭의 상태를 제어 컨트롤러
  int _selectedIndex = 2; // 0:채팅, 1:지도, 2:홈, 3:합동주문, 4:마이페이지

  final GlobalKey<DeliveryTabState> _deliveryTabKey =
      GlobalKey<DeliveryTabState>();
  final GlobalKey<FriendTabState> _friendTabKey = GlobalKey<FriendTabState>();

  // 합동 주문 요청 처리 스트림 및 폴백 타이머
  Timer? _pendingRequestCheckTimer;
  StreamSubscription<JointOrderRequestPayload>? _jointOrderRequestSubscription;
  StreamSubscription<JointOrderStatusPayload>? _jointOrderStatusSubscription;
  final Set<String> _handledRequestIds = <String>{};

  // 알림 관련
  bool _showNotificationDropdown = false;
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _unreadCountSubscription;
  final OverlayPortalController _notificationOverlayController =
      OverlayPortalController();

  @override
  void initState() {
    // 위젯이 생성될 때 딱 한번만 호출
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeNotifications();
    _listenNotificationStreams();
    _maybeStartFallbackPolling();
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
    // 위젯이 화면에서 사라질 때 호출
    _pendingRequestCheckTimer?.cancel(); // 타이머 정리
    _jointOrderRequestSubscription?.cancel();
    _jointOrderStatusSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _tabController.dispose(); // TabController 메모리 누수 방지
    super.dispose();
  }

  void _listenNotificationStreams() {
    logDebug('[Home] 🔔 FCM 스트림 구독 시작');

    _jointOrderRequestSubscription = NotificationService.jointOrderRequests.listen((
      payload,
    ) async {
      if (!mounted) {
        logDebug('[Home] ⚠️ Widget이 마운트되지 않음, 다이얼로그 표시 건너뜀');
        return;
      }
      if (_handledRequestIds.contains(payload.requestId)) {
        return;
      }
      _handledRequestIds.add(payload.requestId);
      await _showJointOrderRequestDialog(
        payload.requestId,
        payload.requesterName ?? '익명',
        payload: payload,
      );
    });

    _jointOrderStatusSubscription = NotificationService.jointOrderStatusUpdates
        .listen((payload) {
          if (!mounted) {
            return;
          }
          _handledRequestIds.add(payload.requestId);
          _handleJointOrderStatusUpdate(payload);
        });
  }

  void _maybeStartFallbackPolling() {
    // 기존 타이머가 있다면 정리
    _pendingRequestCheckTimer?.cancel();

    // FCM 상태 로깅
    final fcmEnabled = NotificationService.isFcmEnabled;
    print('[Home] FCM 상태: ${fcmEnabled ? "활성화됨 ✅" : "비활성화됨 ⚠️"}');

    if (!fcmEnabled) {
      print('[Home] ⚠️ FCM이 비활성화되어 있습니다. 푸시 알림을 받을 수 없습니다.');
      print('[Home] 💡 설정 > 알림에서 앱 알림 권한을 허용해주세요.');
    }

    // 폴링 완전 제거 - FCM 푸시로만 합동 주문 알림 처리
    print('[Home] 합동 주문 알림은 FCM 푸시로만 처리됩니다. (폴링 비활성화)');
  }

  /// 합동 주문 요청 다이얼로그
  Future<void> _showJointOrderRequestDialog(
    String requestId,
    String requesterName, {
    JointOrderRequestPayload? payload,
  }) async {
    final buffer = StringBuffer();
    buffer.write('$requesterName님이 요청을 보냈습니다');
    final storeName = payload?.storeName;
    if (storeName != null && storeName.isNotEmpty) {
      buffer.write('\n매장: $storeName');
    }
    final deliveryPlace = payload?.deliveryPlace;
    if (deliveryPlace != null && deliveryPlace.isNotEmpty) {
      buffer.write('\n만남 장소: $deliveryPlace');
    }
    final orderTime = payload?.orderTime;
    if (orderTime != null) {
      buffer.write(
        '\n주문 예정 시간: ${DateFormat('MM/dd HH:mm').format(orderTime)}',
      );
    }
    buffer.write('\n수락하시겠습니까?');

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_active,
              color: Color(0xFF81C784),
              size: 60,
            ),
            const SizedBox(height: 20),
            const Text(
              '합동 주문 요청',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              buffer.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _respondToRequest(requestId, false);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    '거절',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _respondToRequest(requestId, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C784),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    '수락',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 요청에 응답하기
  Future<void> _respondToRequest(String requestId, bool accepted) async {
    try {
      // 현재 사용자의 게시글 ID 가져오기
      final userPostResult = await JointOrderApi.getUserPost();
      if (userPostResult['success'] != true) {
        _showErrorDialog('게시글 정보를 가져올 수 없습니다.');
        return;
      }

      final userPostId = userPostResult['data']['id']?.toString();

      final result = await JointOrderApi.respondToRequest(
        requestId: requestId,
        postId: userPostId!,
        accepted: accepted,
      );

      if (result['success'] == true && mounted) {
        if (accepted) {
          // 수락 시 대기 스낵바 표시
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '수락 완료! 다른 사람의 수락을 기다리는 중...',
                style: TextStyle(fontSize: 14),
              ),
              backgroundColor: Color(0xFF81C784),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );

          if (!NotificationService.isFcmEnabled) {
            // FCM이 비활성화된 환경에서는 기존 폴링 로직 유지
            _startWaitingForMatchCompletion(requestId);
          }
        } else {
          // 거절 시 간단한 스낵바
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('합동 주문 요청을 거절하였습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      logDebug('Joint-order response failed (${e.runtimeType})');
      if (mounted) {
        _showErrorDialog('응답 처리 중 오류가 발생하였습니다.');
      }
    }
  }

  void _handleJointOrderStatusUpdate(JointOrderStatusPayload payload) {
    final normalizedStatus = payload.status.toLowerCase();

    if (normalizedStatus == 'matched') {
      _showMatchCompletedDialog(payload.chatRoomId);
      return;
    }

    if (normalizedStatus == 'accepted') {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('다른 참여자가 합동 주문 요청을 수락하였습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (normalizedStatus == 'rejected' || normalizedStatus == 'timeout') {
      final message = normalizedStatus == 'timeout'
          ? '일부 응답이 없어 매칭이 취소되었습니다.'
          : '거절로 인해 매칭이 취소되었습니다.';
      _showMatchCancelledDialog(message);
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('합동 주문 상태가 ${payload.status}로 변경되었습니다.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 매칭 완료 대기
  void _startWaitingForMatchCompletion(String requestId) {
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final result = await JointOrderApi.checkRequestStatus(requestId);

        if (result['success'] == true) {
          final status = result['data']['status'];

          if (status == 'accepted') {
            timer.cancel();
            if (mounted) {
              // 채팅방 ID 가져오기
              final chatRoomId = result['data']['chat_room_id'];
              _showMatchCompletedDialog(chatRoomId);
            }
          } else if (status == 'rejected' || status == 'timeout') {
            timer.cancel();
            if (mounted) {
              _showMatchCancelledDialog(
                status == 'timeout'
                    ? '일부 응답이 없어 매칭이 취소되었습니다.'
                    : '거절로 인해 매칭이 취소되었습니다.',
              );
            }
          }
        }
      } catch (e) {
        logDebug('Joint-order completion lookup failed (${e.runtimeType})');
      }
    });
  }

  /// 매칭 완료 다이얼로그 (채팅방 ID 포함)
  void _showMatchCompletedDialog(String? chatRoomId) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF81C784).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF81C784),
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '매칭 완료!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '새로운 그룹 채팅방이 개설되었습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                // 채팅방으로 직접 이동
                if (chatRoomId != null) {
                  await _navigateToJointChatRoom(chatRoomId);
                } else {
                  // 채팅 탭으로 이동
                  setState(() {
                    _selectedIndex = 0;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81C784),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                '채팅방으로 이동',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 합동 주문 채팅방으로 이동
  Future<void> _navigateToJointChatRoom(String chatRoomId) async {
    try {
      // 채팅방 정보 가져오기
      final result = await JointOrderApi.getJointChatRoomInfo(chatRoomId);

      if (result['success'] == true) {
        final chatRoomData = result['data'];

        // ChatRoomList 객체 생성
        final chatRoom = ChatRoomList.fromJson(chatRoomData);

        // 채팅방 페이지로 이동
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomPage(chatRoom: chatRoom),
            ),
          );
        }
      } else {
        // 채팅방 정보를 가져올 수 없으면 채팅 탭으로 이동
        setState(() {
          _selectedIndex = 0;
        });
      }
    } catch (e) {
      logDebug('Chat room navigation failed (${e.runtimeType})');
      // 오류 발생 시 채팅 탭으로 이동
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  /// 매칭 취소 다이얼로그
  void _showMatchCancelledDialog([String? message]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            const Text(
              '매칭 취소',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              message ?? '거절로 인해 매칭이 취소되었습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
      ),
    );
  }

  /// 에러 다이얼로그
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _refreshPosts() {
    // 현재 선택된 탭에 따라 해당 탭만 새로고침
    if (_tabController.index == 0) {
      _deliveryTabKey.currentState?.loadPosts();
    } else {
      _friendTabKey.currentState?.loadPosts();
    }
  }

  // 홈 화면 위젯 분리
  Widget _buildHomePage() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
                  onPressed: () async {
                    if (_showNotificationDropdown) {
                      _notificationOverlayController.hide();
                    } else {
                      _notificationOverlayController.show();
                      // 알림 드롭다운 열 때 서버에서 알림 새로고침
                      await AppNotificationApi.fetchNotifications();
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF81C784),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF81C784),
          tabs: const [
            Tab(text: '함께 배달'),
            Tab(text: '같이 먹을 친구 구하기'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // DeliveryTab, FriendTab 내부에서 AutomaticKeepAliveClientMixin을 사용하여 탭 상태 유지 필요
        children: [
          DeliveryTab(key: _deliveryTabKey),
          FriendTab(key: _friendTabKey),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/create-post');
          if (result == true) {
            _refreshPosts();
          }
        },
        backgroundColor: const Color(0xFF81C784),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 최종 UI 구성 및 반환하는 메인 메서드
    // 실제 페이지 위젯
    final List<Widget> pages = [
      const ChatListPage(), // index 0: 채팅방 목록 페이지
      const MapPage(), // index 1: 지도 페이지
      _buildHomePage(), // index 2: 홈 화면
      JointOrderPage(
        onNavigateToChat: () {
          setState(() {
            _selectedIndex = 0; // 채팅 목록 탭으로 전환
          });
        },
      ), // index 3: 합동 주문
      const MyPage(), // index 4: 마이페이지
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      //  _selectedIndex 값에 따라 pages 리스트에서 적절한 화면을 가져와 body에 표시
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 5개 이상일 때 필요
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF81C784),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          // 탭을 터치했을때 호출되는 함수
          setState(() {
            _selectedIndex = index; // 사용자가 누른 탭의 인덱스
          });
          // 지도 탭으로 돌아올 때는 didChangeDependencies에서 자동 새로고침됨
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '채팅',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '합동 주문'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '마이페이지',
          ),
        ],
      ),
    );
  }
}
