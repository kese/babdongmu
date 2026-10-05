import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_list_data.dart';
import '../models/chat_message_data.dart';
import '../models/shared_cart_data.dart';
import '../models/delivery_post_data.dart';
import '../models/notification_data.dart';
import '../services/api.dart';
import '../services/chat_socket_service.dart';
import '../services/app_notification_api.dart';
import '../pages/shared_cart_page.dart';
import '../pages/settlement_page.dart';
import '../dummy_data/dummy.dart';
import 'package:delivery/utils/logging.dart';

class ChatRoomPage extends StatefulWidget {
  final ChatRoomList chatRoom;
  final DeliveryPost? deliveryPost;

  const ChatRoomPage({super.key, required this.chatRoom, this.deliveryPost});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  final NumberFormat _currencyFormatter = NumberFormat.decimalPattern();
  bool _isLoading = true;
  String? _errorMessage;
  String? _nickname;
  bool _isLoadingOlder = false;
  bool _hasMore = false;
  String? _nextCursor;
  final Set<String> _messageKeys = <String>{};
  StreamSubscription<ChatMessage>? _roomSubscription;
  bool _isHost = false; // 방장 여부
  String? _currentUserId; // 현재 사용자 ID
  String? _hostNickname; // 방장 닉네임
  String? _postId; // 게시물 ID
  bool _isSharedCartActive = false; // 공용 장바구니 활성화 상태
  Timer? _receiptPollTimer;
  int? _deliveryFeeFromPost;
  int? _deliveryFeePerPersonFromPost;
  String? _roomStatus;
  int? _maxCapacity; // 서버에서 내려주는 최대 인원
  int? _escrowTotalPoint;
  int? _escrowTargetPoint; // 목표 에스크로 금액 (모든 참여자 결제 완료 시 도달)
  List<TargetParticipantStatus> _targetParticipants =
      const <TargetParticipantStatus>[];
  List<TargetParticipantStatus> _availableParticipants =
      const <TargetParticipantStatus>[];
  bool _roomActionInProgress = false;
  bool _isDashboardExpanded = true; // 대시보드 접기/펴기 상태
  int? _currentMemberCount; // 최신 참여 인원
  Set<String> _selectedParticipantIds = <String>{}; // 주문 확정할 참여자 선택

  bool get _isGroupRoom => widget.chatRoom.roomType == 'group';

  @override
  void initState() {
    super.initState();
    if (widget.deliveryPost != null) {
      _deliveryFeeFromPost = widget.deliveryPost!.deliveryFee;
      _deliveryFeePerPersonFromPost = widget.deliveryPost!.feePerPerson;
    }
    _currentMemberCount = widget.chatRoom.currentPeople;
    _maxCapacity = widget.chatRoom.maxPeople;
    _loadNickname();
    _fetchMessages(); // 위젯이 로드될 때 메시지 내역을 불러옴
    _checkCartStatus(); // 장바구니 상태 확인
    _initRealtimeSubscription();
    _scrollController.addListener(_handleScroll);
  }

  /// AppBar용 간결한 위치 표시: "🍽️ 음식점 · 📍 주소"
  String _formatLocationCompact(String location) {
    if (location.isEmpty) return '장소 미정';

    // "음식점 · 주소" 형식 파싱
    if (location.contains('·')) {
      final parts = location.split('·').map((e) => e.trim()).toList();
      if (parts.length >= 2) {
        return '🍽️ ${parts[0]} · 📍 ${_shortenAddress(parts[1])}';
      }
    }

    // "/" 형식 파싱
    if (location.contains('/')) {
      final parts = location.split('/').map((e) => e.trim()).toList();
      if (parts.length >= 2) {
        return '🍽️ ${parts[0]} · 📍 ${_shortenAddress(parts[1])}';
      }
    }

    return '📍 $location';
  }

  /// 주소 축약 (최대 2개 구간만)
  String _shortenAddress(String address) {
    final parts = address.split(' ');
    if (parts.length > 3) {
      // "충북 충주시 대학로 50" → "충주시 대학로"
      return '${parts[1]} ${parts[2]}';
    }
    return address;
  }

  String _buildMemberCountLabel() {
    final current = _currentMemberCount ?? widget.chatRoom.currentPeople;
    final max = _maxCapacity ?? widget.chatRoom.maxPeople;
    if (max > 0) {
      return '$current/$max';
    }
    return '$current명';
  }

  Future<void> _loadNickname() async {
    final storedUserId = await ApiService.getUserId();
    final storedNickname = await ApiService.getUserNickname();
    setState(() {
      _nickname = storedNickname ?? '나';
      _currentUserId = storedUserId ?? 'me';
    });
    _checkIfHost();
  }

  // 방장 여부 확인
  Future<void> _checkIfHost() async {
    try {
      final currentUserId = await ApiService.getUserId();

      // ChatApi.getChatRoomInfo가 모든 채팅방 정보를 처리하도록 통합
      final response = await ChatApi.getChatRoomInfo(widget.chatRoom.id);

      if (response['success'] == true) {
        final data = _unwrapApiData(response['data']);
        final hostId = data?['host_id'] ?? data?['hostId'];
        final hostNicknameRaw =
            data?['host_nickname'] ??
            data?['hostNickname'] ??
            data?['host_name'] ??
            data?['hostName'];
        final postId =
            data?['post_id']?.toString() ?? data?['postId']?.toString();
        if (mounted && hostId != null) {
          setState(() {
            _isHost = hostId.toString() == currentUserId;
            _postId = postId; // postId 저장
            if (hostNicknameRaw != null) {
              final nickname = hostNicknameRaw.toString().trim();
              if (nickname.isNotEmpty && nickname.toLowerCase() != 'null') {
                _hostNickname = nickname;
              }
            }
          });
        }
        if (postId != null && postId.isNotEmpty) {
          await _loadPostDeliveryFee(postId);
        }
        _applyRoomStatusData(data);
      }
    } catch (e) {
      // 에러 발생 시 방장 아님으로 처리
      if (mounted) {
        setState(() {
          _isHost = false;
        });
      }
    }
  }

  Future<void> _loadPostDeliveryFee(String postId) async {
    try {
      final response = await PostApi.getPost(postId);
      if (response['success'] != true) return;
      final data = _unwrapApiData(response['data']);
      if (data == null) return;

      final deliveryFee = _parseInt(
        data['delivery_fee'] ??
            data['deliveryFee'] ??
            data['delivery_fee_total'] ??
            data['deliveryFeeTotal'],
      );
      final deliveryFeePerPerson = _parseInt(
        data['fee_per_person'] ??
            data['feePerPerson'] ??
            data['delivery_fee_per_person'] ??
            data['deliveryFeePerPerson'],
      );

      if (!mounted) return;
      if (deliveryFee > 0 || deliveryFeePerPerson > 0) {
        setState(() {
          if (deliveryFee > 0) {
            _deliveryFeeFromPost = deliveryFee;
          }
          if (deliveryFeePerPerson > 0) {
            _deliveryFeePerPersonFromPost = deliveryFeePerPerson;
          }
        });
        ApiService.cacheDeliveryFeeInfo(
          roomId: widget.chatRoom.id,
          deliveryFee: deliveryFee > 0
              ? deliveryFee
              : (_deliveryFeeFromPost ?? 0),
          deliveryFeePerPerson: deliveryFeePerPerson > 0
              ? deliveryFeePerPerson
              : _deliveryFeePerPersonFromPost,
        );
      }
    } catch (e) {
      logDebug('Delivery fee lookup failed');
    }
  }

  // 공용 장바구니 상태 확인

  Future<void> _checkCartStatus() async {
    try {
      final response = await SharedCartApi.getSharedCart(
        roomId: widget.chatRoom.id,
      );
      if (response['success'] == true) {
        final data = _unwrapApiData(response['data']);
        final bool isActive = _parseBoolFlag(
          data?['is_active'] ?? data?['isActive'] ?? data?['active'],
        );
        if (mounted) {
          setState(() {
            _isSharedCartActive = isActive;
          });
        }
      }
    } catch (e) {
      // 상태 확인 실패는 무시
      logDebug('Cart status lookup failed');
    }
  }

  Map<String, dynamic>? _unwrapApiData(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final nested = raw['data'];
      if (nested is Map<String, dynamic>) {
        return _unwrapApiData(nested);
      }
      return raw;
    }
    return null;
  }

  bool _parseBoolFlag(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return false;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '');
      final parsed = int.tryParse(cleaned);
      if (parsed != null) {
        return parsed;
      }
      final parsedDouble = double.tryParse(cleaned);
      if (parsedDouble != null) {
        return parsedDouble.round();
      }
    }
    return 0;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _roomSubscription?.cancel();
    _receiptPollTimer?.cancel();
    super.dispose();
  }

  // 스크롤을 맨 아래로 이동시키는 함수
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // API를 호출하여 메시지 목록을 가져오는 함수
  Future<void> _fetchMessages() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await ChatApi.getChatMessages(widget.chatRoom.id);
      if (result['success'] == true) {
        final fetched = _deserializeMessages(result['data']);
        final meta = result['meta'];
        if (mounted) {
          setState(() {
            _messages = List<ChatMessage>.of(fetched);
            _messageKeys
              ..clear()
              ..addAll(fetched.map(_keyForMessage));
            _applyMeta(meta, reset: true);
            _errorMessage = null;
          });
          _scrollToBottom();
          await _restoreCachedReceiptIfNeeded();
          await _reloadRoomStatus();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result['message']?.toString() ?? '메시지를 불러오지 못했습니다.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '네트워크 오류가 발생했습니다.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startReceiptPolling();
      }
    }
  }

  void _handleScroll() {
    if (!_hasMore || _isLoadingOlder) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 48) {
      _loadOlderMessages();
    }
  }

  Future<void> _initRealtimeSubscription() async {
    try {
      await _roomSubscription?.cancel();
      await ChatSocketService.instance.ensureConnected();
      if (!mounted) return;
      _roomSubscription = await ChatSocketService.instance.subscribeToRoom(
        roomId: widget.chatRoom.id,
        onMessage: _handleRealtimeMessage,
      );
    } catch (_) {
      debugPrint('실시간 채팅 구독 실패');
      if (!mounted) return;
      setState(() {
        _errorMessage = '실시간 채팅 연결에 실패했습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.';
      });
    }
  }

  void _handleRealtimeMessage(ChatMessage message) {
    if (!mounted) return;
    final key = _keyForMessage(message);
    if (_messageKeys.contains(key)) {
      return;
    }
    setState(() {
      if (message.isMe) {
        final idx = _messages.lastIndexWhere(
          (m) =>
              m.isMe &&
              m.id.startsWith('local_') &&
              m.message == message.message,
        );
        if (idx != -1) {
          final placeholderKey = _keyForMessage(_messages[idx]);
          _messageKeys.remove(placeholderKey);
          _messages[idx] = message;
          _messageKeys.add(key);
          _errorMessage = null;
          return;
        }
      }
      _messageKeys.add(key);
      _messages.add(message);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _errorMessage = null;
    });
    _scrollToBottom();
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMore) {
      return;
    }
    final cursor = _nextCursor;
    if (cursor == null || cursor.isEmpty) {
      return;
    }

    _isLoadingOlder = true;
    final previousExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final previousOffset = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;

    try {
      final result = await ChatApi.getChatMessages(
        widget.chatRoom.id,
        cursorMessageId: cursor,
      );

      if (result['success'] == true) {
        final older = _deserializeMessages(result['data']);
        final meta = result['meta'];

        if (mounted && older.isNotEmpty) {
          setState(() {
            final List<ChatMessage> toInsert = [];
            for (final message in older) {
              final key = _keyForMessage(message);
              if (_messageKeys.add(key)) {
                toInsert.add(message);
              }
            }

            if (toInsert.isNotEmpty) {
              _messages = [...toInsert, ..._messages];
            }

            _applyMeta(meta, reset: false);
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients) return;
            final newExtent = _scrollController.position.maxScrollExtent;
            final offset = newExtent - previousExtent + previousOffset;
            final safeOffset = offset.clamp(
              _scrollController.position.minScrollExtent,
              _scrollController.position.maxScrollExtent,
            );
            _scrollController.jumpTo(safeOffset);
          });
        } else {
          if (mounted) {
            setState(() {
              _applyMeta(meta, reset: false);
            });
          }
        }
      }
    } catch (_) {
      // 과거 데이터 불러오기 실패는 무시하고 다음 기회에 재시도
    } finally {
      _isLoadingOlder = false;
    }
  }

  void _applyMeta(dynamic meta, {required bool reset}) {
    if (meta is Map) {
      final normalized = meta.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final hasNextRaw = normalized['hasNext'] ?? normalized['has_next'];
      final nextCursorRaw =
          normalized['nextCursor'] ?? normalized['next_cursor'];

      final hasNext =
          hasNextRaw == true || hasNextRaw == 'true' || hasNextRaw == 1;
      final nextCursor = nextCursorRaw?.toString();

      if (hasNext && nextCursor != null && nextCursor.isNotEmpty) {
        _hasMore = true;
        _nextCursor = nextCursor;
      } else {
        _hasMore = false;
        _nextCursor = null;
      }
    } else if (reset) {
      _hasMore = false;
      _nextCursor = null;
    }
  }

  String _keyForMessage(ChatMessage message) {
    if (message.id.isNotEmpty) {
      return message.id;
    }
    return '${message.senderId}_${message.timestamp.microsecondsSinceEpoch}_${message.message.hashCode}';
  }

  List<ChatMessage> _deserializeMessages(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) {
            if (item is Map) {
              final normalized = item.map(
                (key, value) => MapEntry(key.toString(), value),
              );
              return ChatMessage.fromJson(normalized);
            }
            return null;
          })
          .whereType<ChatMessage>()
          .toList();
    }
    return <ChatMessage>[];
  }

  // 방장이 아닌 사용자가 + 버튼 클릭 시
  void _showNonHostMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('방장만 주문을 시작할 수 있습니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 방장이 + 버튼 클릭 시 메뉴 표시
  void _showOrderMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.shopping_cart,
                    color: Color(0xFF81C784),
                  ),
                  title: const Text(
                    '주문하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startOrder();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 주문 시작 (공용 장바구니 활성화)
  Future<void> _startOrder() async {
    try {
      final response = await SharedCartApi.activateSharedCart(
        roomId: widget.chatRoom.id,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _isSharedCartActive = true;
        });

        // 알림 추가
        final notification = NotificationData(
          id: 'shared_order_start_${DateTime.now().millisecondsSinceEpoch}',
          type: 'shared_order_start',
          title: '공용 장바구니 활성화',
          message:
              '"${widget.chatRoom.postTitle}"에서 공용 장바구니가 활성화 되었습니다! 주문하러 가기',
          timestamp: DateTime.now(),
          metadata: {'chatRoomId': widget.chatRoom.id},
        );
        await AppNotificationApi.addNotification(notification);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주문이 시작되었습니다. 상단 배너를 확인하세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('주문 시작에 실패했습니다')));
      }
    }
  }

  // 상단 배너에서 주문하기 버튼 클릭
  Future<void> _openSharedCart() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedCartPage(
          roomId: widget.chatRoom.id,
          isHost: _isHost,
          linkedPostId: _postId,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    SharedCartSummary? summary;
    bool completed = false;

    if (result is SharedCartSummary) {
      summary = result;
      completed = true;
    } else if (result is Map<String, dynamic>) {
      summary = SharedCartSummary.fromJson(result);
      completed = true;
    } else if (result == true) {
      completed = true;
    }

    // 공용 장바구니에서 완료 처리되면 메시지 새로고침 및 배너 숨김
    if (completed) {
      setState(() {
        _isSharedCartActive = false;
      });

      if (summary != null) {
        await _fetchMessages();
        if (!mounted) return;
        await _insertReceiptMessage(summary);
      } else {
        await _addReceiptToChat();
        await _fetchMessages();
      }
    }
  }

  // 영수증 메시지를 채팅에 추가
  Future<void> _addReceiptToChat({SharedCartSummary? summary}) async {
    if (summary != null) {
      await _insertReceiptMessage(summary);
      return;
    }

    // 개발 모드에서는 임시 저장소에서 영수증 가져오기
    if (ApiService.isDevelopment) {
      final receipt = DummyDataCache.tempReceipts[widget.chatRoom.id];
      if (receipt != null) {
        // tempChatMessages에 영수증 추가
        final roomId = widget.chatRoom.id;
        if (!DummyDataCache.tempChatMessages.containsKey(roomId)) {
          DummyDataCache.tempChatMessages[roomId] = [];
        }
        DummyDataCache.tempChatMessages[roomId]!.add(receipt);
      }
    }
  }

  Future<void> _insertReceiptMessage(SharedCartSummary summary) async {
    if (!mounted) return;
    final systemMessage = _buildReceiptSystemMessage(summary);
    final timestamp = _resolveReceiptTimestamp(summary);
    final receiptId = summary.cartId.isNotEmpty
        ? 'local_receipt_${summary.cartId}'
        : 'local_receipt_${timestamp.millisecondsSinceEpoch}';

    setState(() {
      final existingIndex = _messages.indexWhere(
        (m) => m.type == 'receipt' && m.cartSummary?.cartId == summary.cartId,
      );

      if (existingIndex != -1) {
        final existing = _messages[existingIndex];
        final resolvedId = existing.id.isNotEmpty ? existing.id : receiptId;
        _messages[existingIndex] = existing.copyWith(
          id: resolvedId,
          message: systemMessage,
          timestamp: timestamp,
          cartSummary: summary,
        );
      } else {
        final receiptMessage = ChatMessage(
          id: receiptId,
          senderId: 'system',
          senderName: '시스템',
          message: systemMessage,
          timestamp: timestamp,
          isMe: false,
          type: 'receipt',
          cartSummary: summary,
        );
        final key = _keyForMessage(receiptMessage);
        if (_messageKeys.add(key)) {
          _messages.add(receiptMessage);
        } else {
          final duplicateIndex = _messages.indexWhere(
            (m) => _keyForMessage(m) == key,
          );
          if (duplicateIndex != -1) {
            _messages[duplicateIndex] = receiptMessage;
          } else {
            _messages.add(receiptMessage);
          }
        }
      }

      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });

    await _cacheReceiptSummary(
      summary,
      message: systemMessage,
      timestamp: timestamp,
    );
    _scrollToBottom();
  }

  // 시스템 메시지를 채팅에 추가하는 헬퍼 함수
  Future<void> _addSystemMessage(String message) async {
    if (!mounted) return;

    final systemMessage = ChatMessage(
      id: 'system_${DateTime.now().microsecondsSinceEpoch}',
      senderId: 'system',
      senderName: '시스템',
      message: message,
      timestamp: DateTime.now(),
      isMe: false,
      type: 'system',
    );

    final messageKey = _keyForMessage(systemMessage);

    setState(() {
      if (_messageKeys.add(messageKey)) {
        _messages.add(systemMessage);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
    });

    _scrollToBottom();

    // 서버에도 메시지 전송
    try {
      await ChatApi.sendChatMessage(
        roomId: widget.chatRoom.id,
        message: message,
      );
    } catch (e) {
      logDebug('System message send failed');
    }
  }

  String _buildReceiptSystemMessage(SharedCartSummary summary) {
    final status = summary.receiptStatus.toLowerCase();
    if (status == 'finalized') {
      return '정산이 완료되었습니다.';
    }
    if (status == 'pending_settlement' || status == 'pending') {
      return '정산이 필요합니다. 송금을 진행해 주세요.';
    }
    return '정산 상태를 확인해 주세요.';
  }

  DateTime _resolveReceiptTimestamp(SharedCartSummary summary) {
    if (summary.receiptStatus.toLowerCase() == 'finalized' &&
        summary.finalizedAt != null) {
      return summary.finalizedAt!;
    }
    return summary.createdAt;
  }

  bool _shouldReplaceReceiptSummary(
    SharedCartSummary? current,
    SharedCartSummary next,
  ) {
    if (current == null) {
      return true;
    }
    if (current.receiptStatus != next.receiptStatus) {
      return true;
    }
    if (current.finalizedAt == null && next.finalizedAt != null) {
      return true;
    }
    if (current.totalPrice != next.totalPrice) {
      return true;
    }
    if (current.totalMenuPrice != next.totalMenuPrice) {
      return true;
    }
    if (current.deliveryFee != next.deliveryFee) {
      return true;
    }
    return false;
  }

  String _receiptStatusLabel(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'finalized') {
      return '정산 완료';
    }
    if (normalized == 'pending_settlement' || normalized == 'pending') {
      return '정산 대기';
    }
    return '상태 확인';
  }

  Color _receiptStatusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'finalized') {
      return const Color(0xFF2E7D32);
    }
    if (normalized == 'pending_settlement' || normalized == 'pending') {
      return const Color(0xFFFFA000);
    }
    return const Color(0xFF607D8B);
  }

  String _formatCurrency(int amount) {
    return '${_currencyFormatter.format(amount)}원';
  }

  Future<void> _cacheReceiptSummary(
    SharedCartSummary summary, {
    String? message,
    DateTime? timestamp,
  }) async {
    final resolvedMessage = message ?? _buildReceiptSystemMessage(summary);
    final resolvedTimestamp = timestamp ?? _resolveReceiptTimestamp(summary);
    DummyDataCache.tempReceipts[widget.chatRoom.id] = {
      'sender_id': 'system',
      'sender_name': '시스템',
      'message': resolvedMessage,
      'timestamp': resolvedTimestamp.toIso8601String(),
      'type': 'receipt',
      'cart_summary': summary.toJson(),
    };
    await _persistReceipt(summary);
  }

  Future<void> _clearReceiptCache() async {
    final roomId = widget.chatRoom.id;
    final tempCached = DummyDataCache.tempReceipts[roomId];
    SharedCartSummary? tempSummary;
    if (tempCached is Map<String, dynamic>) {
      final summaryMap = _coerceMap(
        tempCached['cart_summary'] ?? tempCached['cartSummary'],
      );
      if (summaryMap != null) {
        tempSummary = SharedCartSummary.fromJson(summaryMap);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final persistedRaw = prefs.getString('receipt_$roomId');
    SharedCartSummary? persistedSummary;
    if (persistedRaw != null && persistedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(persistedRaw);
        if (decoded is Map<String, dynamic>) {
          persistedSummary = SharedCartSummary.fromJson(decoded);
        } else if (decoded is Map) {
          final normalized = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          persistedSummary = SharedCartSummary.fromJson(normalized);
        }
      } catch (_) {
        persistedSummary = null;
      }
    }

    bool shouldRemoveTemp = true;
    if (tempSummary != null) {
      final status = tempSummary.receiptStatus.toLowerCase();
      if (status == 'finalized') {
        shouldRemoveTemp = false;
      }
    }

    bool shouldRemovePersisted = true;
    if (persistedSummary != null) {
      final status = persistedSummary.receiptStatus.toLowerCase();
      if (status == 'finalized') {
        shouldRemovePersisted = false;
      }
    }

    final Set<String> cartIdsToRemove = <String>{};
    if (shouldRemoveTemp &&
        tempSummary != null &&
        tempSummary.cartId.isNotEmpty) {
      cartIdsToRemove.add(tempSummary.cartId);
    }
    if (shouldRemovePersisted &&
        persistedSummary != null &&
        persistedSummary.cartId.isNotEmpty) {
      cartIdsToRemove.add(persistedSummary.cartId);
    }

    if (shouldRemoveTemp) {
      DummyDataCache.tempReceipts.remove(roomId);
    }
    if (shouldRemovePersisted) {
      await prefs.remove('receipt_$roomId');
    }

    if (!mounted) {
      return;
    }

    final bool removeReceiptsWithoutSummary =
        shouldRemoveTemp || shouldRemovePersisted;

    setState(() {
      _messages = _messages.where((m) {
        if (m.type != 'receipt') {
          return true;
        }
        final summary = m.cartSummary;
        if (summary == null) {
          return !removeReceiptsWithoutSummary;
        }
        final status = summary.receiptStatus.toLowerCase();
        if (status == 'finalized') {
          return true;
        }
        final cartId = summary.cartId;
        if (cartId.isNotEmpty && cartIdsToRemove.contains(cartId)) {
          return false;
        }
        if (cartId.isEmpty && removeReceiptsWithoutSummary) {
          return false;
        }
        return true;
      }).toList();
      _messageKeys
        ..clear()
        ..addAll(_messages.map(_keyForMessage));
    });
  }

  Future<void> _restoreCachedReceiptIfNeeded() async {
    final roomId = widget.chatRoom.id;
    final cached = DummyDataCache.tempReceipts[roomId];
    if (await _tryInsertReceiptFromRaw(cached)) {
      return;
    }
    final persisted = await _loadPersistedReceipt();
    if (persisted == null) return;
    final existingIndex = _messages.indexWhere(
      (m) => m.cartSummary?.cartId == persisted.cartId,
    );
    if (existingIndex != -1) {
      final existingSummary = _messages[existingIndex].cartSummary;
      if (!_shouldReplaceReceiptSummary(existingSummary, persisted)) {
        return;
      }
    }
    if (!mounted) return;
    await _insertReceiptMessage(persisted);
  }

  Future<bool> _tryInsertReceiptFromRaw(dynamic raw) async {
    if (raw is! Map<String, dynamic>) return false;
    final summaryData = raw['cart_summary'] ?? raw['cartSummary'];
    final summaryMap = _coerceMap(summaryData);
    if (summaryMap == null) return false;
    final summary = SharedCartSummary.fromJson(summaryMap);
    final existingIndex = _messages.indexWhere(
      (m) => m.type == 'receipt' && m.cartSummary?.cartId == summary.cartId,
    );
    if (existingIndex != -1) {
      final existingSummary = _messages[existingIndex].cartSummary;
      if (!_shouldReplaceReceiptSummary(existingSummary, summary)) {
        return true;
      }
    }
    if (!mounted) return false;
    await _insertReceiptMessage(summary);
    return true;
  }

  Future<void> _persistReceipt(SharedCartSummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'receipt_${widget.chatRoom.id}';
    await prefs.setString(key, jsonEncode(summary.toJson()));
  }

  Future<SharedCartSummary?> _loadPersistedReceipt() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'receipt_${widget.chatRoom.id}';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SharedCartSummary.fromJson(decoded);
      }
      if (decoded is Map) {
        return SharedCartSummary.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void _startReceiptPolling() {
    _receiptPollTimer?.cancel();
    _ensureReceiptVisibleFromServer();
    _receiptPollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _ensureReceiptVisibleFromServer(),
    );
  }

  Future<void> _ensureReceiptVisibleFromServer() async {
    if (!mounted) return;
    SharedCartSummary? existingReceipt;
    for (final message in _messages) {
      if (message.type == 'receipt' && message.cartSummary != null) {
        existingReceipt = message.cartSummary;
        break;
      }
    }
    if (existingReceipt != null &&
        existingReceipt.receiptStatus.toLowerCase() == 'finalized') {
      _receiptPollTimer?.cancel();
      return;
    }

    final bool hasCachedReceipt =
        existingReceipt != null ||
        DummyDataCache.tempReceipts.containsKey(widget.chatRoom.id);

    try {
      final response = await SharedCartApi.getSharedCart(
        roomId: widget.chatRoom.id,
      );
      if (response['success'] != true) {
        if (response['statusCode'] == 404 && hasCachedReceipt) {
          await _clearReceiptCache();
        }
        return;
      }
      final data = _unwrapApiData(response['data']);
      if (data == null) {
        if (hasCachedReceipt) {
          await _clearReceiptCache();
        }
        return;
      }
      final cart = SharedCart.fromJson(data);
      final hostUser = cart.items.firstWhere(
        (item) => item.userId == cart.hostId,
        orElse: () => cart.items.isNotEmpty
            ? cart.items.first
            : const CartMenuItem(
                id: '',
                name: '',
                price: 0,
                userId: '',
                userNickname: '방장',
              ),
      );

      final bool cartCompleted = cart.isCompleted;
      final bool hasItems = cart.items.isNotEmpty;
      final bool hasValidId = cart.id.isNotEmpty;

      if (!cartCompleted || !hasItems || !hasValidId) {
        if (hasCachedReceipt) {
          await _clearReceiptCache();
        }
        return;
      }
      final menuTotal = cart.totalPrice;
      final participantCount = cart.items
          .map((item) => item.userId)
          .toSet()
          .length;
      final resolvedDeliveryFee =
          _deliveryFeeFromPost != null && _deliveryFeeFromPost! > 0
          ? _deliveryFeeFromPost!
          : (_deliveryFeePerPersonFromPost != null &&
                    _deliveryFeePerPersonFromPost! > 0 &&
                    participantCount > 0
                ? _deliveryFeePerPersonFromPost! * participantCount
                : 0);

      final computedDeliveryFeePerPerson =
          participantCount > 0 && resolvedDeliveryFee > 0
          ? (resolvedDeliveryFee / participantCount).ceil()
          : null;
      final deliveryFeePerPerson =
          computedDeliveryFeePerPerson ??
          (_deliveryFeePerPersonFromPost != null &&
                  _deliveryFeePerPersonFromPost! > 0
              ? _deliveryFeePerPersonFromPost!
              : null);

      final summary = SharedCartSummary(
        cartId: cart.id,
        items: cart.items,
        totalMenuPrice: menuTotal,
        totalPrice: resolvedDeliveryFee > 0
            ? menuTotal + resolvedDeliveryFee
            : menuTotal,
        deliveryFee: resolvedDeliveryFee,
        hostId: cart.hostId,
        hostNickname: hostUser.userNickname.isNotEmpty
            ? hostUser.userNickname
            : '방장',
        createdAt: cart.completedAt ?? DateTime.now(),
        finalizedAt: null,
        receiptStatus: 'pending_settlement',
        deliveryFeePerPerson: deliveryFeePerPerson,
      );

      if (deliveryFeePerPerson != null && deliveryFeePerPerson > 0) {
        ApiService.cacheDeliveryFeeInfo(
          roomId: widget.chatRoom.id,
          deliveryFee: resolvedDeliveryFee,
          deliveryFeePerPerson: deliveryFeePerPerson,
        );
      }
      final exists = _messages.any(
        (m) => m.cartSummary?.cartId == summary.cartId,
      );
      if (exists) {
        _receiptPollTimer?.cancel();
        return;
      }
      if (!mounted) return;
      await _insertReceiptMessage(summary);
      _receiptPollTimer?.cancel();
    } catch (e) {
      logDebug('Receipt sync failed');
    }
  }

  bool get _shouldShowRoomStatusPanel {
    if (_normalizedRoomStatus.isNotEmpty) {
      return true;
    }
    if (_targetParticipants.isNotEmpty) {
      return true;
    }
    if (_isHost && _availableParticipants.isNotEmpty) {
      return true;
    }
    return false;
  }

  String get _normalizedRoomStatus {
    final status = _roomStatus?.trim() ?? '';
    return status.toUpperCase();
  }

  TargetParticipantStatus? get _selfTargetParticipant {
    final currentId = _currentUserId?.trim();
    if (currentId == null || currentId.isEmpty) {
      return null;
    }
    for (final participant in _targetParticipants) {
      if (participant.userId == currentId) {
        return participant;
      }
    }
    return null;
  }

  int get _confirmedReceptionCount {
    return _targetParticipants
        .where((participant) => participant.hasConfirmedReception)
        .length;
  }

  String _roomStatusLabel(String code) {
    switch (code) {
      case 'GATHERING':
        return '모집중';
      case 'BEFORE_ORDER':
      case 'ORDER_BEFORE':
        return '주문 전';
      case 'ORDERING':
        return '주문중';
      case 'READY_TO_PAY':
        return '결제 대기';
      case 'READY_TO_START':
        return '배달 준비 완료';
      case 'IN_PROGRESS':
      case 'DELIVERING':
        return '배달 진행 중';
      case 'COMPLETED':
        return '정산 완료';
      case 'CANCELLED':
        return '취소됨';
      case 'DISPUTED':
        return '분쟁 처리 중';
      default:
        return code.isEmpty ? '상태 미정' : code;
    }
  }

  Widget _buildRoomStatusPanel() {
    final statusCode = _normalizedRoomStatus;
    final statusLabel = _roomStatusLabel(statusCode);
    final confirmedCount = _confirmedReceptionCount;
    // 확정 인원 계산: 주문 확정이 완료된 경우에만 _targetParticipants 사용
    // 주문 확정 전에는 현재 참여 인원 표시, 확정 후에는 확정 인원 표시
    final isOrderFinalized =
        statusCode == 'ORDERING' ||
        statusCode == 'READY_TO_START' ||
        statusCode == 'DELIVERING' ||
        statusCode == 'IN_PROGRESS' ||
        statusCode == 'COMPLETED';
    // 주문 확정 전: 현재 참여 인원, 확정 후: 확정된 인원
    final totalTargets = (isOrderFinalized && _targetParticipants.isNotEmpty)
        ? _targetParticipants.length
        : (_availableParticipants.isNotEmpty
              ? _availableParticipants.length
              : (_currentMemberCount ?? widget.chatRoom.currentPeople));
    final isTargeted = _selfTargetParticipant != null;
    final hasConfirmed = _selfTargetParticipant?.hasConfirmedReception ?? false;
    final hasReported = _selfTargetParticipant?.hasReportedIssue ?? false;
    // 결제 완료 여부 확인
    final hasPaid = _selfTargetParticipant?.hasPaid ?? false;
    final paymentStatus =
        _selfTargetParticipant?.paymentStatus.toLowerCase() ?? '';
    final isPaymentCompleted =
        hasPaid ||
        paymentStatus == 'completed' ||
        paymentStatus == 'paid' ||
        paymentStatus == 'approved';

    // 주문 확정 버튼: 영수증이 채팅에 실제로 표시된 후에만 표시
    // 영수증이 메시지 리스트에 존재하는지 확인
    final hasReceiptInMessages = _messages.any(
      (m) => m.type == 'receipt' && m.cartSummary != null,
    );
    final bool canFinalizeOrder =
        _isHost &&
        hasReceiptInMessages && // 영수증이 채팅에 실제로 표시되어야 함
        (statusCode.isEmpty ||
            statusCode == 'GATHERING' ||
            statusCode == 'BEFORE_ORDER' ||
            statusCode == 'ORDER_BEFORE');
    // 정산 완료 후 배달 시작 버튼 표시 (방장만)
    // ORDERING 상태에서 모든 참여자(방장 포함)가 결제를 완료했을 때 표시
    // 방법 1: 참여자별 hasPaid 필드 확인 (서버에서 제공하는 경우)
    final bool allParticipantsPaidByField =
        _targetParticipants.isNotEmpty &&
        _targetParticipants.every((p) => p.hasPaid);
    // 방법 2: 에스크로 금액으로 확인 (escrowTotalPoint >= escrowTargetPoint)
    final bool allParticipantsPaidByEscrow =
        _escrowTargetPoint != null &&
        _escrowTargetPoint! > 0 &&
        _escrowTotalPoint != null &&
        _escrowTotalPoint! >= _escrowTargetPoint!;
    // 둘 중 하나라도 true면 결제 완료로 판단
    final bool allParticipantsPaid =
        allParticipantsPaidByField || allParticipantsPaidByEscrow;
    final bool isEscrowReady =
        _escrowTotalPoint != null &&
        _escrowTotalPoint! > 0 &&
        allParticipantsPaid;

    // 모든 참여자가 수령 확인을 완료했는지 확인
    final allReceptionsConfirmed =
        totalTargets > 0 && confirmedCount >= totalTargets;
    // 배달 시작 버튼: 배달이 시작되지 않았고, 모든 수령 확인이 완료되지 않았을 때만 표시
    final bool canStartDelivery =
        _isHost &&
        !allReceptionsConfirmed && // 모든 수령 확인 완료 시 숨김
        ((statusCode == 'ORDERING' && isEscrowReady) ||
            statusCode == 'READY_TO_START');


    // COMPLETED 상태에서는 배달 시작 버튼 표시 안 함
    // 결제하기 버튼: ORDERING 상태에서 결제가 완료되지 않은 경우 표시
    // READY_TO_PAY 상태도 유지 (하위 호환성)
    final bool canRequestPayment =
        isTargeted &&
        (statusCode == 'ORDERING' || statusCode == 'READY_TO_PAY') &&
        !isPaymentCompleted;
    // 배달 시작 후 수령 확인 버튼 표시 (참여자만, 배달 진행 중일 때만)
    final bool canConfirmReception =
        isTargeted &&
        (statusCode == 'IN_PROGRESS' || statusCode == 'DELIVERING') &&
        !hasConfirmed;
    // 배달 시작 후 문제 신고 버튼 표시 (참여자만, 배달 진행 중일 때만)
    final bool canReportIssue =
        isTargeted &&
        (statusCode == 'IN_PROGRESS' || statusCode == 'DELIVERING');

    final actionButtons = <Widget>[];

    // 모든 수령 확인이 완료된 경우 완료 메시지 표시
    if (allReceptionsConfirmed && totalTargets > 0) {
      actionButtons.add(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF81C784), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                '모든 참여자가 수령을 확인했습니다.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4CAF50),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (canFinalizeOrder) {
      actionButtons.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _roomActionInProgress ? null : _handleFinalizeOrder,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('이 인원으로 주문 확정'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ),
      );
    }

    if (canStartDelivery) {
      actionButtons.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _roomActionInProgress ? null : _handleStartDelivery,
            icon: const Icon(Icons.delivery_dining),
            label: const Text('배달 시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ),
      );
    }

    if (canRequestPayment) {
      actionButtons.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _roomActionInProgress ? null : _handleRequestPayment,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('결제하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ),
      );
    }

    if (canConfirmReception) {
      actionButtons.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _roomActionInProgress ? null : _handleConfirmReception,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('수령 확인'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ),
      );
    }

    if (canReportIssue) {
      actionButtons.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _roomActionInProgress || hasReported
                ? null
                : _handleReportIssue,
            icon: const Icon(Icons.report_problem_outlined),
            label: Text(hasReported ? '문제 신고 완료' : '문제 신고'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD84315),
              side: const BorderSide(color: Color(0xFFD84315)),
            ),
          ),
        ),
      );
    }

    final infoTexts = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '방 상태: $statusLabel',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (_escrowTotalPoint != null && _escrowTotalPoint! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 14,
                    color: Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '포인트 ${_formatCurrency(_escrowTotalPoint!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];

    // 확정 인원 표시: 주문 확정 전에는 현재 참여 인원, 확정 후에는 확정 인원
    final capacityLabel = () {
      if (totalTargets == 0) {
        return null;
      }
      // 주문 확정 전/후 구분하여 라벨 변경
      final label = isOrderFinalized ? '확정 인원' : '참여 인원';
      if (_maxCapacity != null && _maxCapacity! > 0) {
        return '$label: $totalTargets/${_maxCapacity!}명';
      }
      return '$label: $totalTargets명';
    }();

    // 인원이 있을 때만 표시
    if (capacityLabel != null) {
      infoTexts.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            capacityLabel,
            style: const TextStyle(fontSize: 13, color: Color(0xFF607D8B)),
          ),
        ),
      );
    }

    if (totalTargets > 0) {
      infoTexts.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '수령 확인: $confirmedCount/$totalTargets명',
            style: const TextStyle(fontSize: 13, color: Color(0xFF607D8B)),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBF7),
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 대시보드 제목 (접기/펴기 가능)
          InkWell(
            onTap: () {
              setState(() {
                _isDashboardExpanded = !_isDashboardExpanded;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                const Icon(
                  Icons.dashboard_outlined,
                  size: 16,
                  color: Color(0xFF263238),
                ),
                const SizedBox(width: 6),
                const Text(
                  '대시보드',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF263238),
                  ),
                ),
                const Spacer(),
                Icon(
                  _isDashboardExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),

          // 대시보드 내용 (접혔을 때는 표시하지 않음)
          if (_isDashboardExpanded) ...[
            const SizedBox(height: 12),
            ...infoTexts,

            // 주문 인원 확정 UI (BEFORE_ORDER 상태이고 방장일 때)
            if (_isHost &&
                (statusCode.isEmpty ||
                    statusCode == 'BEFORE_ORDER' ||
                    statusCode == 'ORDER_BEFORE' ||
                    statusCode == 'GATHERING') &&
                _availableParticipants.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildParticipantSelectionSection(),
            ],

            // 참여자 현황 추가
            if (totalTargets > 0) ...[
              const SizedBox(height: 12),
              _buildParticipantStatusSection(),
            ],

            if (actionButtons.isNotEmpty) ...[const SizedBox(height: 12)],
            for (var i = 0; i < actionButtons.length; i++) ...[
              actionButtons[i],
              if (i != actionButtons.length - 1) const SizedBox(height: 8),
            ],
          ] else ...[
            // 접혔을 때는 기본 정보만 표시
            const SizedBox(height: 8),
            infoTexts.first,
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantSelectionSection() {
    // 초기 선택: _targetParticipants가 있으면 그것을 사용, 없으면 모든 참여자 선택
    if (_selectedParticipantIds.isEmpty) {
      if (_targetParticipants.isNotEmpty) {
        _selectedParticipantIds = _targetParticipants
            .map((p) => p.userId)
            .where((id) => id.isNotEmpty)
            .toSet();
      } else {
        // 현재 사용자 포함 모든 참여자 선택
        _selectedParticipantIds = _availableParticipants
            .map((p) => p.userId)
            .where((id) => id.isNotEmpty)
            .toSet();
        if (_currentUserId != null && _currentUserId!.isNotEmpty) {
          _selectedParticipantIds.add(_currentUserId!);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2196F3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 16,
                color: Color(0xFF2196F3),
              ),
              const SizedBox(width: 6),
              const Text(
                '주문 인원 확정',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2196F3),
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedParticipantIds.length}명 선택',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '주문에 포함할 참여자를 선택하세요',
            style: TextStyle(fontSize: 11, color: Color(0xFF607D8B)),
          ),
          const SizedBox(height: 8),
          ..._availableParticipants.map((participant) {
            final isSelected = _selectedParticipantIds.contains(
              participant.userId,
            );
            final isCurrentUser = participant.userId == _currentUserId;
            final displayName = participant.nickname.isNotEmpty
                ? participant.nickname
                : (isCurrentUser ? '나' : '알 수 없음');

            return CheckboxListTile(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedParticipantIds.add(participant.userId);
                  } else {
                    _selectedParticipantIds.remove(participant.userId);
                  }
                });
                // 선택된 참여자들을 _targetParticipants에 반영
                _updateTargetParticipantsFromSelection();
              },
              title: Text(displayName, style: const TextStyle(fontSize: 13)),
              subtitle: isCurrentUser
                  ? const Text(
                      '(방장)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50)),
                    )
                  : null,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
          // 현재 사용자가 참여자 목록에 없으면 추가
          if (_currentUserId != null &&
              _currentUserId!.isNotEmpty &&
              !_availableParticipants.any(
                (p) => p.userId == _currentUserId,
              )) ...[
            CheckboxListTile(
              value: _selectedParticipantIds.contains(_currentUserId),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedParticipantIds.add(_currentUserId!);
                  } else {
                    _selectedParticipantIds.remove(_currentUserId!);
                  }
                });
                _updateTargetParticipantsFromSelection();
              },
              title: const Text('나 (방장)', style: TextStyle(fontSize: 13)),
              subtitle: const Text(
                '(방장)',
                style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50)),
              ),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ],
      ),
    );
  }

  void _updateTargetParticipantsFromSelection() {
    // 선택된 참여자 ID를 기반으로 _targetParticipants 업데이트
    final selectedParticipants = <TargetParticipantStatus>[];

    for (final participant in _availableParticipants) {
      if (_selectedParticipantIds.contains(participant.userId)) {
        selectedParticipants.add(participant);
      }
    }

    // 현재 사용자가 선택되었지만 목록에 없으면 추가
    if (_currentUserId != null &&
        _currentUserId!.isNotEmpty &&
        _selectedParticipantIds.contains(_currentUserId) &&
        !_availableParticipants.any((p) => p.userId == _currentUserId)) {
      selectedParticipants.add(
        TargetParticipantStatus(
          userId: _currentUserId!,
          nickname: _nickname ?? '나',
          hasPaid: false,
          paymentStatus: 'pending',
          hasConfirmedReception: false,
          hasReportedIssue: false,
        ),
      );
    }

    setState(() {
      _targetParticipants = selectedParticipants;
    });
  }

  Widget _buildParticipantStatusSection() {
    // 참여자 상태별 그룹화
    final paidParticipants = _targetParticipants
        .where(
          (p) =>
              p.hasPaid == true ||
              p.paymentStatus.toLowerCase() == 'completed' ||
              p.paymentStatus.toLowerCase() == 'paid' ||
              p.paymentStatus.toLowerCase() == 'approved',
        )
        .toList();

    final unpaidParticipants = _targetParticipants
        .where(
          (p) =>
              p.hasPaid != true &&
              p.paymentStatus.toLowerCase() != 'completed' &&
              p.paymentStatus.toLowerCase() != 'paid' &&
              p.paymentStatus.toLowerCase() != 'approved',
        )
        .toList();

    final confirmedParticipants = _targetParticipants
        .where((p) => p.hasConfirmedReception == true)
        .toList();
    final unconfirmedParticipants = _targetParticipants
        .where((p) => p.hasConfirmedReception != true)
        .toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참여자 현황 (${_targetParticipants.length}명)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37474F),
            ),
          ),
          const SizedBox(height: 8),

          // 결제 상태
          _buildParticipantStatusRow(
            '결제 완료',
            '${paidParticipants.length}명',
            paidParticipants
                .map((p) => p.nickname.isEmpty ? '알 수 없음' : p.nickname)
                .toList(),
            const Color(0xFF43A047),
            Icons.check_circle_outline,
          ),

          _buildParticipantStatusRow(
            '참여자',
            '${unpaidParticipants.length}명',
            unpaidParticipants
                .map((p) => p.nickname.isEmpty ? '알 수 없음' : p.nickname)
                .toList(),
            const Color(0xFFFF9800),
            Icons.access_time,
          ),

          // 수령 확인 상태 (배달 시작 후에만 표시)
          if (_roomStatus == 'in_progress') ...[
            const SizedBox(height: 4),
            _buildParticipantStatusRow(
              '수령 확인',
              '${confirmedParticipants.length}명',
              confirmedParticipants
                  .map((p) => p.nickname.isEmpty ? '알 수 없음' : p.nickname)
                  .toList(),
              const Color(0xFF1E88E5),
              Icons.inventory_2_outlined,
            ),

            _buildParticipantStatusRow(
              '수령 대기',
              '${unconfirmedParticipants.length}명',
              unconfirmedParticipants
                  .map((p) => p.nickname.isEmpty ? '알 수 없음' : p.nickname)
                  .toList(),
              const Color(0xFF9E9E9E),
              Icons.pending_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantStatusRow(
    String label,
    String count,
    List<String> participants,
    Color color,
    IconData icon,
  ) {
    if (participants.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        InkWell(
          onTap: () {
            _showParticipantDetailDialog(label, participants, color);
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  '$label: $count',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.expand_more, size: 14, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showParticipantDetailDialog(
    String title,
    List<String> participants,
    Color color,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              title.contains('완료')
                  ? Icons.check_circle_outline
                  : title.contains('대기')
                  ? Icons.access_time
                  : title.contains('수령')
                  ? Icons.inventory_2_outlined
                  : Icons.pending_outlined,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: participants
                .map(
                  (nickname) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Color(0xFF607D8B),
                        ),
                        const SizedBox(width: 8),
                        Text(nickname, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _coerceMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, val) => MapEntry(key.toString(), val));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _showSimpleSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleFinalizeOrder() async {
    if (_roomActionInProgress) {
      return;
    }
    final participantIds = _resolveFinalizeParticipants();
    if (participantIds.isEmpty) {
      _showSimpleSnack('확정할 참여자가 없습니다.');
      return;
    }

    var participantCount = participantIds.length;
    if (participantCount == 0 && _availableParticipants.isNotEmpty) {
      participantCount = _availableParticipants.length;
    }

    // 활성 공용 장바구니에서 cartId 가져오기
    String? cartId;
    try {
      final response = await SharedCartApi.getSharedCart(
        roomId: widget.chatRoom.id,
      );
      if (response['success'] == true) {
        final data = _unwrapApiData(response['data']);
        if (data != null) {
          final cart = SharedCart.fromJson(data);
          cartId = cart.id;
        }
      }
    } catch (e) {
      logDebug('Cart id lookup failed');
    }

    if (cartId == null || cartId.isEmpty) {
      _showSimpleSnack('활성된 공용 장바구니를 찾을 수 없습니다.');
      return;
    }

    final totalPoint = await _calculateFinalizeTotalPoint(participantCount);
    if (totalPoint == null || totalPoint <= 0) {
      _showSimpleSnack('총 결제 금액을 계산하지 못했습니다.');
      return;
    }

    if (!mounted) return;
    setState(() => _roomActionInProgress = true);

    try {
      final response = await RoomOrderApi.finalizeOrder(
        roomId: widget.chatRoom.id,
        targetParticipantIds: participantIds,
        cartId: cartId,
        totalPoint: totalPoint,
        memo: '주문 확정',
      );

      if (response['success'] == true) {
        _showSimpleSnack('주문을 확정했습니다.');
        // 시스템 메시지 추가
        await _addSystemMessage('주문이 확정되었습니다.');
        await _reloadRoomStatus();
      } else {
        final message = response['message']?.toString();
        _showSimpleSnack(message ?? '주문 확정에 실패했습니다.');
      }
    } catch (e) {
      logDebug('Order finalization failed');
      _showSimpleSnack('주문 확정 중 문제가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _roomActionInProgress = false);
      }
    }
  }

  Future<void> _handleStartDelivery() async {
    if (_roomActionInProgress) {
      return;
    }
    if (!mounted) return;
    setState(() => _roomActionInProgress = true);

    try {
      final response = await RoomOrderApi.startDelivery(
        roomId: widget.chatRoom.id,
      );

      if (response['success'] == true) {
        _showSimpleSnack('배달을 시작했습니다.');
        // 시스템 메시지 추가
        await _addSystemMessage('배달이 시작되었습니다.');
        await _reloadRoomStatus();
      } else {
        final message = response['message']?.toString();
        _showSimpleSnack(message ?? '배달 시작에 실패했습니다.');
      }
    } catch (e) {
      logDebug('Delivery start failed');
      _showSimpleSnack('배달을 시작하지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() => _roomActionInProgress = false);
      }
    }
  }

  Future<void> _handleConfirmReception() async {
    if (_roomActionInProgress) {
      return;
    }
    if (!mounted) return;
    setState(() => _roomActionInProgress = true);

    try {
      final response = await RoomOrderApi.confirmReception(
        roomId: widget.chatRoom.id,
      );

      if (response['success'] == true) {
        _showSimpleSnack('수령을 확인했습니다.');
        // 시스템 메시지 추가
        final myNickname = _nickname ?? '나';
        await _addSystemMessage('$myNickname님이 수령을 확인했습니다.');
        await _reloadRoomStatus();
      } else {
        final message = response['message']?.toString();
        _showSimpleSnack(message ?? '수령 확인에 실패했습니다.');
      }
    } catch (e) {
      logDebug('Receipt confirmation failed');
      _showSimpleSnack('수령 확인 중 문제가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _roomActionInProgress = false);
      }
    }
  }

  Future<void> _handleReportIssue() async {
    if (_roomActionInProgress) {
      return;
    }
    if (!mounted) return;
    setState(() => _roomActionInProgress = true);

    try {
      final response = await RoomOrderApi.reportIssue(
        roomId: widget.chatRoom.id,
      );

      if (response['success'] == true) {
        _showSimpleSnack('문제 신고를 접수했습니다.');
        // 시스템 메시지 추가
        final myNickname = _nickname ?? '나';
        await _addSystemMessage('$myNickname님이 문제를 신고했습니다.');
        await _reloadRoomStatus();
      } else {
        final message = response['message']?.toString();
        _showSimpleSnack(message ?? '문제 신고에 실패했습니다.');
      }
    } catch (e) {
      logDebug('Issue report failed');
      _showSimpleSnack('문제 신고 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _roomActionInProgress = false);
      }
    }
  }

  Future<void> _handleRequestPayment() async {
    if (_roomActionInProgress) {
      return;
    }
    if (!mounted) return;
    setState(() => _roomActionInProgress = true);

    try {
      var summary = _latestReceiptSummary();
      if (summary == null) {
        await _ensureReceiptVisibleFromServer();
        summary = _latestReceiptSummary();
      }

      if (summary == null) {
        _showSimpleSnack('정산 정보가 아직 준비되지 않았습니다.');
        return;
      }

      _openSettlement(summary);
    } finally {
      if (mounted) {
        setState(() => _roomActionInProgress = false);
      }
    }
  }

  Future<void> _reloadRoomStatus() async {
    try {
      final response = await ChatApi.getChatRoomInfo(widget.chatRoom.id);
      if (response['success'] == true) {
        final data = _unwrapApiData(response['data']);
        _applyRoomStatusData(data);
      }
    } catch (e) {
      logDebug('Room status refresh failed');
    }
  }

  void _applyRoomStatusData(Map<String, dynamic>? data) {
    if (data == null) {
      return;
    }

    final status = _firstString([
      data['room_status'],
      data['roomStatus'],
      data['status'],
      data['room_state'],
    ]);

    final escrowPoint = _firstInt([
      data['escrow_total_point'],
      data['escrowTotalPoint'],
      data['escrow_point'],
    ], defaultValue: _escrowTotalPoint ?? 0);

    final escrowTarget = _firstInt([
      data['escrow_target_point'],
      data['escrowTargetPoint'],
      data['target_point'],
    ], defaultValue: _escrowTargetPoint ?? 0);

    final targetsRaw =
        data['target_participants'] ?? data['targetParticipants'];
    final participantsRaw =
        data['participants'] ??
        data['participantList'] ??
        data['members'] ??
        data['currentParticipants'];

    final targetList = _parseParticipantList(targetsRaw);
    final participantList = _parseParticipantList(participantsRaw);

    final resolvedTargets = targetList.isNotEmpty
        ? targetList
        : (participantList.isNotEmpty
              ? List<TargetParticipantStatus>.of(participantList)
              : <TargetParticipantStatus>[]);

    final memberCountFromData = _firstInt([
      data['member_count'],
      data['memberCount'],
      data['current_people'],
      data['currentPeople'],
      data['current_participants'],
      data['currentParticipants'],
    ], defaultValue: participantList.length);

    final resolvedMemberCount = memberCountFromData > 0
        ? memberCountFromData
        : (participantList.isNotEmpty
              ? participantList.length
              : (_currentMemberCount ?? widget.chatRoom.currentPeople));

    final maxCapacityFromData = _firstInt([
      data['max_capacity'],
      data['maxCapacity'],
      data['capacity'],
      data['participantLimit'],
      data['maxParticipants'],
    ], defaultValue: _maxCapacity ?? widget.chatRoom.maxPeople);

    final resolvedMaxCapacity = () {
      final fallback = _maxCapacity ?? widget.chatRoom.maxPeople;
      var value = maxCapacityFromData > 0 ? maxCapacityFromData : fallback;
      if (value < resolvedMemberCount) {
        value = resolvedMemberCount;
      }
      return value;
    }();

    if (!mounted) {
      return;
    }

    setState(() {
      if (status != null && status.isNotEmpty) {
        _roomStatus = status;
      }
      _maxCapacity = resolvedMaxCapacity;
      _currentMemberCount = resolvedMemberCount;
      _escrowTotalPoint = escrowPoint;
      _escrowTargetPoint = escrowTarget;
      _targetParticipants = resolvedTargets;
      _availableParticipants = participantList;
    });
  }

  List<TargetParticipantStatus> _parseParticipantList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .map(TargetParticipantStatus.fromJson)
          .toList(growable: false);
    }
    if (raw is Map) {
      final normalized = raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return [TargetParticipantStatus.fromJson(normalized)];
    }
    return const <TargetParticipantStatus>[];
  }

  List<String> _resolveFinalizeParticipants() {
    final ids = <String>{};

    // 1. 선택된 참여자 ID가 있으면 우선 사용
    if (_selectedParticipantIds.isNotEmpty) {
      for (final id in _selectedParticipantIds) {
        final trimmedId = id.trim();
        if (trimmedId.isNotEmpty) {
          ids.add(trimmedId);
        }
      }
    }

    // 2. _targetParticipants가 있으면 사용
    if (ids.isEmpty) {
      for (final participant in _targetParticipants) {
        final id = participant.userId.trim();
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }

    // 3. 그래도 비어있으면 모든 참여자 사용
    if (ids.isEmpty) {
      for (final participant in _availableParticipants) {
        final id = participant.userId.trim();
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
      // 현재 사용자도 추가
      final currentId = _currentUserId?.trim();
      if (currentId != null && currentId.isNotEmpty) {
        ids.add(currentId);
      }
    }

    return ids.toList(growable: false);
  }

  Future<int?> _calculateFinalizeTotalPoint(int participantCount) async {
    try {
      final response = await SharedCartApi.getSharedCart(
        roomId: widget.chatRoom.id,
      );
      if (response['success'] != true) {
        final message = response['message']?.toString();
        if (message != null && message.isNotEmpty) {
          _showSimpleSnack(message);
        }
        return null;
      }

      final data = _unwrapApiData(response['data']);
      if (data == null) {
        return null;
      }

      final cart = SharedCart.fromJson(data);
      final menuTotal = cart.totalPrice;

      var resolvedParticipantCount = participantCount;
      if (resolvedParticipantCount <= 0) {
        resolvedParticipantCount = cart.items
            .map((item) => item.userId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .length;
      }

      final deliveryFee = _resolveFinalizeDeliveryFee(resolvedParticipantCount);
      final total = deliveryFee > 0 ? menuTotal + deliveryFee : menuTotal;
      return total > 0 ? total : menuTotal;
    } catch (e) {
      logDebug('Payment total calculation failed');
      return null;
    }
  }

  int _resolveFinalizeDeliveryFee(int participantCount) {
    if (_deliveryFeeFromPost != null && _deliveryFeeFromPost! > 0) {
      return _deliveryFeeFromPost!;
    }
    if (_deliveryFeePerPersonFromPost != null &&
        _deliveryFeePerPersonFromPost! > 0 &&
        participantCount > 0) {
      return _deliveryFeePerPersonFromPost! * participantCount;
    }
    final cachedFee = ApiService.getDeliveryFeeInfo(widget.chatRoom.id);
    if (cachedFee != null) {
      final perPerson = cachedFee['deliveryFeePerPerson'];
      if (perPerson != null && perPerson > 0 && participantCount > 0) {
        return perPerson * participantCount;
      }
      final total = cachedFee['deliveryFee'];
      if (total != null && total > 0) {
        return total;
      }
    }
    return 0;
  }

  SharedCartSummary? _latestReceiptSummary() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final message = _messages[i];
      if (message.type == 'receipt' && message.cartSummary != null) {
        return message.cartSummary;
      }
    }
    return null;
  }

  String? _firstString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      if (candidate is String) {
        final trimmed = candidate.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
          continue;
        }
        return trimmed;
      }
      final asString = candidate.toString();
      if (asString.isNotEmpty && asString.toLowerCase() != 'null') {
        return asString;
      }
    }
    return null;
  }

  int _firstInt(List<dynamic> candidates, {int defaultValue = 0}) {
    for (final candidate in candidates) {
      final parsed = _tryParseInt(candidate);
      if (parsed != null) {
        return parsed;
      }
    }
    return defaultValue;
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '');
      if (cleaned.isEmpty) {
        return null;
      }
      final asInt = int.tryParse(cleaned);
      if (asInt != null) {
        return asInt;
      }
      final asDouble = double.tryParse(cleaned);
      if (asDouble != null) {
        return asDouble.round();
      }
    }
    return null;
  }

  // 메시지 전송 함수
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // (개발 모드)서버 응답을 기다리지 않고 UI에 바로 추가
    final myNickname = _nickname ?? '나';

    final newMessage = ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      senderId: 'me', // 임시 ID
      senderName: myNickname,
      message: messageText,
      timestamp: DateTime.now(), // 현재 시간으로 설정
      isMe: true,
    );
    final messageKey = _keyForMessage(newMessage);

    setState(() {
      _messageKeys.add(messageKey);
      _messages.add(newMessage); // UI에 즉시 반영
      _messageController.clear(); // 입력창 비우기
    });
    _scrollToBottom(); // 메시지 전송 후 스크롤을 맨 아래로 이동

    // 실제 API 호출
    try {
      await ChatApi.sendChatMessage(
        roomId: widget.chatRoom.id,
        message: messageText,
      );
    } catch (e) {
      // 에러 처리 (예: '메시지 전송 실패' 스낵바 표시)
      debugPrint('메시지 전송 실패');
      if (!mounted) return;
      setState(() {
        _messages.remove(newMessage);
        _messageKeys.remove(messageKey);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메시지 전송에 실패했습니다.')));
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.chatRoom.postTitle,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  _formatLocationCompact(widget.chatRoom.location),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.people_outline,
                size: 16,
                color: const Color(0xFF81C784),
              ),
              const SizedBox(width: 4),
              Text(
                _buildMemberCountLabel(),
                style: const TextStyle(
                  color: Color(0xFF81C784),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0, left: 8.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.chatRoom.postType),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.chatRoom.postType,
                style: TextStyle(
                  color: _getStatusTextColor(widget.chatRoom.postType),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_shouldShowRoomStatusPanel) _buildRoomStatusPanel(),
          if (_isSharedCartActive) _buildOrderBanner(),
          Expanded(child: _buildMessageArea()),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF81C784)),
      );
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    final bannerCount = _isGroupRoom ? 1 : 0;
    final totalItems = _messages.length + bannerCount;

    if (totalItems == 0) {
      return const Center(
        child: Text('아직 메시지가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: false, // 최신 메시지가 아래에 표시되도록
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        final isBannerIndex = _isGroupRoom && index == 0;
        if (isBannerIndex) {
          return _buildGroupRoomInfoBanner();
        }

        final messageIndex = _isGroupRoom ? index - 1 : index;
        final message = _messages[messageIndex];
        return _buildMessageItem(message);
      },
    );
  }

  Widget _buildGroupRoomInfoBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.groups_2, color: Color(0xFF1565C0)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '합동 주문 그룹 채팅방',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '여러 게시글의 참여자가 모인 방입니다. 모든 참여자가 자동으로 추가되며 공용 장바구니와 정산 기능을 함께 사용할 수 있어요.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 상단 고정 배너 (주문 진행 중)
  Widget _buildOrderBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: Color(0xFF81C784), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주문 진행 중',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF81C784),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '메뉴를 추가하세요',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _openSharedCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81C784),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              '주문하기',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 말풍선 UI
  Widget _buildMessageItem(ChatMessage message) {
    // 영수증 메시지인 경우 특별한 UI 표시
    if (message.type == 'receipt' && message.cartSummary != null) {
      return _buildReceiptMessage(message);
    }

    // 시스템 메시지인 경우 특별한 UI 표시
    if (message.type == 'system') {
      return _buildSystemMessage(message);
    }

    // 일반 메시지
    // 24시간 형식(HH:mm)
    final formattedTime = DateFormat('HH:mm').format(message.timestamp);

    final alignment = message.isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final bubbleColor = message.isMe
        ? const Color(0xFF81C784)
        : Colors.grey[200];
    final textColor = message.isMe ? Colors.white : Colors.black;

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(25),
      topRight: const Radius.circular(25),
      bottomLeft: message.isMe ? const Radius.circular(25) : Radius.zero,
      bottomRight: message.isMe ? Radius.zero : const Radius.circular(25),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!message.isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Text(
                message.senderName,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          Row(
            mainAxisAlignment: message.isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.isMe)
                Text(
                  formattedTime,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              if (message.isMe) const SizedBox(width: 8),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: bubbleRadius,
                ),
                child: Text(
                  message.message,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
              ),
              if (!message.isMe) const SizedBox(width: 8),
              if (!message.isMe)
                Text(
                  formattedTime,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 시스템 메시지 UI
  Widget _buildSystemMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.message,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ),
      ),
    );
  }

  // 영수증 메시지 UI
  Widget _buildReceiptMessage(ChatMessage message) {
    final summary = message.cartSummary!;
    final formattedTime = DateFormat('HH:mm').format(message.timestamp);
    final statusLabel = _receiptStatusLabel(summary.receiptStatus);
    final statusColor = _receiptStatusColor(summary.receiptStatus);
    final isFinalized = summary.receiptStatus.toLowerCase() == 'finalized';

    // 사용자별로 그룹화
    final Map<String, List<CartMenuItem>> groupedItems = {};
    for (final item in summary.items) {
      if (!groupedItems.containsKey(item.userNickname)) {
        groupedItems[item.userNickname] = [];
      }
      groupedItems[item.userNickname]!.add(item);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 시스템 메시지
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.message,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 영수증 카드
          GestureDetector(
            onTap: () => _openReceipt(summary),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFF81C784), width: 2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 헤더
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          color: Color(0xFF81C784),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '주문 영수증',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF81C784),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 주문 내역 (최대 3개만 표시)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...groupedItems.entries.take(3).map((entry) {
                          final nickname = entry.key;
                          final items = entry.value;
                          final subtotal = items.fold(
                            0,
                            (sum, item) => sum + item.price,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$nickname (${items.length}개)',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Text(
                                  _formatCurrency(subtotal),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (groupedItems.length > 3)
                          Text(
                            '외 ${groupedItems.length - 3}명...',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('메뉴 총액', style: TextStyle(fontSize: 14)),
                            Text(
                              _formatCurrency(summary.totalMenuPrice),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (summary.deliveryFee > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('배달비', style: TextStyle(fontSize: 14)),
                              Text(
                                _formatCurrency(summary.deliveryFee),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (summary.deliveryFeePerPerson != null &&
                            summary.deliveryFeePerPerson! > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '1인당 배달비',
                                style: TextStyle(fontSize: 14),
                              ),
                              Text(
                                _formatCurrency(summary.deliveryFeePerPerson!),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '총 결제 금액',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatCurrency(summary.totalPrice),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF81C784),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 16,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '탭하여 상세 내역 확인',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 정산하기 버튼
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isFinalized ? null : () => _openSettlement(summary),
              icon: const Icon(Icons.payment),
              label: Text(
                isFinalized ? '정산 완료' : '정산하기',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81C784),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 영수증 클릭 시 공용 장바구니 페이지 열기 (읽기 전용)
  void _openReceipt(SharedCartSummary summary) {
    final cart = SharedCart(
      id: summary.cartId,
      roomId: widget.chatRoom.id,
      isActive: false, // 완료된 장바구니
      items: summary.items,
      hostId: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedCartPage(
          roomId: widget.chatRoom.id,
          isHost: _isHost,
          initialCart: cart,
          linkedPostId: _postId,
        ),
      ),
    );
  }

  // 정산하기 버튼 클릭 시
  Future<void> _openSettlement(SharedCartSummary summary) async {
    if (summary.receiptStatus.toLowerCase() == 'finalized') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 정산이 완료되었습니다.')));
      return;
    }

    // 내가 주문한 메뉴만 필터링
    final myItems = summary.items
        .where((item) => item.userId == _currentUserId)
        .toList();

    if (myItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문한 메뉴가 없습니다.')));
      return;
    }

    // 메뉴 금액 합계
    final myItemsTotal = myItems.fold(0, (sum, item) => sum + item.price);

    // 인당 배달비 계산 (총 배달비를 인원수로 나눔)
    final userCount = summary.items.map((item) => item.userId).toSet().length;
    final summaryItemsTotal = summary.items.fold(
      0,
      (sum, item) => sum + item.price,
    );
    final deliveryFeePerPerson = _resolveDeliveryFeePerPerson(
      summary: summary,
      participantCount: userCount,
      summaryItemsTotal: summaryItemsTotal,
    );

    final totalAmount = myItemsTotal + deliveryFeePerPerson;

    logDebug(
      '[Settlement] 총 배달비: ${summary.deliveryFee}, 인원: $userCount, 인당: $deliveryFeePerPerson',
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementPage(
          roomId: widget.chatRoom.id,
          cartId: summary.cartId,
          currentUserId: _currentUserId ?? '',
          myItems: myItems,
          deliveryFeePerPerson: deliveryFeePerPerson,
          totalAmount: totalAmount,
          hostNickname: _resolveHostNickname(summary),
          isHost: _isHost, // 방장 여부 전달
        ),
      ),
    );

    // 정산이 완료되었으면 방 상태를 다시 로드하여 배달 시작 버튼이 표시되도록 함
    if (result != null &&
        result is Map &&
        result['settlementUpdated'] == true) {
      // 시스템 메시지 추가
      final myNickname = _nickname ?? '나';
      await _addSystemMessage('$myNickname님이 정산을 완료했습니다.');
      // 상태 업데이트를 위해 잠시 대기 후 재로드
      await Future.delayed(const Duration(milliseconds: 500));
      await _reloadRoomStatus();
      // 추가로 한 번 더 확인 (서버 상태 반영 지연 고려)
      await Future.delayed(const Duration(milliseconds: 1000));
      await _reloadRoomStatus();
    }
  }

  String _resolveHostNickname(SharedCartSummary summary) {
    if (_hostNickname != null) {
      final trimmed = _hostNickname!.trim();
      if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
        return trimmed;
      }
    }
    if (_isHost && _nickname != null && _nickname!.trim().isNotEmpty) {
      return _nickname!;
    }
    final summaryNickname = summary.hostNickname.trim();
    if (summaryNickname.isNotEmpty && summaryNickname.toLowerCase() != 'null') {
      return summaryNickname;
    }
    final hostId = summary.hostId.trim();
    if (hostId.isNotEmpty) {
      for (final item in summary.items) {
        final itemUserId = item.userId.trim();
        if (itemUserId.isEmpty) {
          continue;
        }
        if (itemUserId == hostId) {
          final nickname = item.userNickname.trim();
          if (nickname.isNotEmpty && nickname.toLowerCase() != 'null') {
            return nickname;
          }
        }
      }
    }
    return '방장';
  }

  int _resolveDeliveryFeePerPerson({
    required SharedCartSummary summary,
    required int participantCount,
    required int summaryItemsTotal,
  }) {
    final menuTotal = summary.totalMenuPrice > 0
        ? summary.totalMenuPrice
        : summaryItemsTotal;

    final summaryPerPerson = summary.deliveryFeePerPerson;
    if (summaryPerPerson != null && summaryPerPerson > 0) {
      return summaryPerPerson;
    }

    final summaryDeliveryFee = summary.deliveryFee > 0
        ? summary.deliveryFee
        : (summary.totalPrice > menuTotal ? summary.totalPrice - menuTotal : 0);
    if (summaryDeliveryFee > 0 && participantCount > 0) {
      return (summaryDeliveryFee / participantCount).ceil();
    }

    final cachedFee = ApiService.getDeliveryFeeInfo(widget.chatRoom.id);
    if (cachedFee != null) {
      final cachedPerPerson = cachedFee['deliveryFeePerPerson'];
      if (cachedPerPerson != null && cachedPerPerson > 0) {
        return cachedPerPerson;
      }
      final cachedTotal = cachedFee['deliveryFee'];
      if (cachedTotal != null && cachedTotal > 0 && participantCount > 0) {
        return (cachedTotal / participantCount).ceil();
      }
    }

    if (_deliveryFeePerPersonFromPost != null &&
        _deliveryFeePerPersonFromPost! > 0) {
      return _deliveryFeePerPersonFromPost!;
    }

    final fromWidgetPost = widget.deliveryPost?.feePerPerson;
    if (fromWidgetPost != null && fromWidgetPost > 0) {
      return fromWidgetPost;
    }

    if (_deliveryFeeFromPost != null &&
        _deliveryFeeFromPost! > 0 &&
        participantCount > 0) {
      return (_deliveryFeeFromPost! / participantCount).ceil();
    }

    final fallbackTotal = summary.totalPrice - menuTotal;
    final totalDeliveryFee =
        _deliveryFeeFromPost ??
        widget.deliveryPost?.deliveryFee ??
        (fallbackTotal > 0 ? fallbackTotal : 0);

    if (totalDeliveryFee <= 0 || participantCount <= 0) {
      return 0;
    }
    return (totalDeliveryFee / participantCount).ceil();
  }

  // 전송 버튼에 _sendMessage 함수 연결
  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1.0)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: Colors.grey[600],
                size: 28,
              ),
              onPressed: () {
                // 방장 & 주문이 활성화되지 않았을 때만 메뉴 표시
                if (_isHost && !_isSharedCartActive) {
                  _showOrderMenu();
                } else if (_isHost && _isSharedCartActive) {
                  // 이미 주문이 시작되었다는 메시지 표시 (선택적)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이미 주문이 진행 중입니다.')),
                  );
                } else {
                  _showNonHostMessage();
                }
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: null,
                // 엔터키로 전송
                textInputAction: TextInputAction.send,
                onSubmitted: (text) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF81C784), size: 28),
              onPressed: _sendMessage, // (8) 전송 함수 호출
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
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

  Color _getStatusTextColor(String status) {
    switch (status) {
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
}
