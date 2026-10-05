import 'dart:async';

import 'package:flutter/material.dart';
import 'package:delivery/utils/logging.dart';
import '../models/shared_cart_data.dart';
import '../models/delivery_post_data.dart';
import '../services/api.dart';
import '../pages/store_menu_picker_screen.dart';

class SharedCartPage extends StatefulWidget {
  final String roomId;
  final bool isHost;
  final SharedCart? initialCart;
  final List<TargetParticipantStatus>? participantStatuses;
  final String? linkedPostId; // 연결된 게시물 ID 추가

  const SharedCartPage({
    super.key,
    required this.roomId,
    required this.isHost,
    this.initialCart,
    this.participantStatuses,
    this.linkedPostId, // 게시물 ID 파라미터 추가
  });

  @override
  State<SharedCartPage> createState() => _SharedCartPageState();
}

class _SharedCartPageState extends State<SharedCartPage> {
  SharedCart? _cart;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isReadOnly = false; // true when 주문 완료 상태
  bool _needsActivation = false; // 주문 시작 전 대기 상태
  bool _isActivatingCart = false;
  Timer? _cartPollTimer;
  String? _currentUserId; // 현재 사용자 ID
  String? _storeName; // 게시글의 가게 이름

  List<TargetParticipantStatus> get _participantStatuses =>
      widget.participantStatuses ?? const <TargetParticipantStatus>[];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadPostInfo(); // 게시글 정보 로드
    if (widget.initialCart != null) {
      _cart = widget.initialCart;
      _isReadOnly = widget.initialCart!.isCompleted;
      _needsActivation =
          !widget.initialCart!.isActive && !widget.initialCart!.isCompleted;
      _isLoading = false;
      _startCartPolling();
    } else {
      _loadCart();
    }
  }

  /// 게시글 정보를 불러와서 가게 이름 추출
  Future<void> _loadPostInfo() async {
    if (widget.linkedPostId == null || widget.linkedPostId!.isEmpty) {
      return;
    }

    try {
      final response = await PostApi.getPost(widget.linkedPostId!);
      if (response['success'] == true) {
        final postData = response['data'];
        if (postData != null) {
          final post = DeliveryPost.fromJson(
            postData is Map<String, dynamic>
                ? postData
                : Map<String, dynamic>.from(postData as Map),
          );
          if (mounted) {
            setState(() {
              _storeName = post.storeName;
            });
          }
        }
      }
    } catch (e) {
      logDebug('Shared cart post lookup failed (${e.runtimeType})');
    }
  }

  // 현재 사용자 ID 불러오기
  Future<void> _loadCurrentUserId() async {
    try {
      final storedUserId = await ApiService.getUserId();
      setState(() {
        _currentUserId = storedUserId ?? 'me';
      });
    } catch (e) {
      logDebug('Current user lookup failed (${e.runtimeType})');
      setState(() {
        _currentUserId = 'me';
      });
    }
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SharedCartApi.getSharedCart(roomId: widget.roomId);
      final cartData = _unwrapApiData(response['data']);
      if (response['success'] == true && cartData != null) {
        if (!mounted) return;
        setState(() {
          _cart = SharedCart.fromJson(cartData);
          _isReadOnly = _cart!.isCompleted;
          _needsActivation = !_cart!.isActive && !_cart!.isCompleted;
          _isLoading = false;
        });
        _startCartPolling();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = '장바구니를 불러올 수 없습니다';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '오류가 발생했습니다';
        _isLoading = false;
      });
    }
  }

  Future<void> _activateCart() async {
    if (_isActivatingCart || _cart == null) return;
    setState(() {
      _isActivatingCart = true;
    });

    try {
      final response = await SharedCartApi.activateSharedCart(
        roomId: widget.roomId,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        SharedCart? updatedCart;
        final data = _unwrapApiData(response['data']);
        if (data != null) {
          updatedCart = SharedCart.fromJson(data);
        } else {
          updatedCart = _cart;
        }

        if (updatedCart != null && !updatedCart.isActive) {
          updatedCart = updatedCart.copyWith(isActive: true);
        }

        setState(() {
          _cart = updatedCart ?? _cart;
          if (_cart != null) {
            _isReadOnly = _cart!.isCompleted;
            _needsActivation = !_cart!.isActive && !_cart!.isCompleted;
          }
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문이 시작되었습니다. 메뉴를 추가해 주세요.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? '주문 시작에 실패했습니다')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문 시작에 실패했습니다')));
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingCart = false;
        });
      }
    }
  }

  Future<void> _addMenuItem() async {
    // 가게 이름이 있고 비어있지 않으면 메뉴 선택 옵션 제공
    if (_storeName != null && _storeName!.isNotEmpty) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('메뉴 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_storeName의 메뉴를 선택하시겠습니까?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                '또는 직접 메뉴 정보를 입력할 수 있습니다.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'manual'),
              child: const Text('직접 입력'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'select'),
              child: const Text(
                '메뉴 선택',
                style: TextStyle(
                  color: Color(0xFF81C784),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (action == 'select') {
        // 메뉴 선택 화면으로 이동
        final menuResult = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => StoreMenuPickerScreen(
              storeName: _storeName!,
            ),
          ),
        );

        if (menuResult != null && mounted) {
          await _addMenuItemToCart(
            name: menuResult['name'] as String,
            price: menuResult['price'] as int,
          );
          return;
        }
      } else if (action == null) {
        // 취소된 경우
        return;
      }
      // action == 'manual'인 경우 아래 직접 입력 다이얼로그로 진행
    }

    // 직접 입력 다이얼로그
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AddMenuDialog(),
    );

    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final price = result['price'] as int;

    await _addMenuItemToCart(name: name, price: price);
  }

  /// 메뉴를 장바구니에 추가하는 공통 로직
  Future<void> _addMenuItemToCart({
    required String name,
    required int price,
  }) async {
    try {
      final response = await SharedCartApi.addMenuItem(
        roomId: widget.roomId,
        name: name,
        price: price,
      );

      final itemData = _unwrapApiData(response['data']);

      if (response['success'] == true && itemData != null) {
        final newItem = CartMenuItem.fromJson(itemData);
        if (!mounted) return;
        setState(() {
          _cart = SharedCart(
            id: _cart!.id,
            roomId: _cart!.roomId,
            isActive: _cart!.isActive,
            items: [..._cart!.items, newItem],
            hostId: _cart!.hostId,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메뉴 추가에 실패했습니다')));
    }
  }

  Future<void> _editMenuItem(CartMenuItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddMenuDialog(
        initialName: item.name,
        initialPrice: item.price,
        isEdit: true,
      ),
    );

    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final price = result['price'] as int;

    try {
      final response = await SharedCartApi.updateMenuItem(
        roomId: widget.roomId,
        itemId: item.id,
        name: name,
        price: price,
      );

      if (response['success'] == true) {
        if (!mounted) return;
        setState(() {
          final index = _cart!.items.indexWhere((i) => i.id == item.id);
          if (index != -1) {
            final updatedItems = List<CartMenuItem>.from(_cart!.items);
            updatedItems[index] = CartMenuItem(
              id: item.id,
              name: name,
              price: price,
              userId: item.userId,
              userNickname: item.userNickname,
            );
            _cart = SharedCart(
              id: _cart!.id,
              roomId: _cart!.roomId,
              isActive: _cart!.isActive,
              items: updatedItems,
              hostId: _cart!.hostId,
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메뉴 수정에 실패했습니다')));
    }
  }

  Future<void> _deleteMenuItem(CartMenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메뉴 삭제'),
        content: Text('${item.name}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final response = await SharedCartApi.deleteMenuItem(
        roomId: widget.roomId,
        itemId: item.id,
      );

      if (response['success'] == true) {
        if (!mounted) return;
        setState(() {
          _cart = _cart?.copyWith(
            items: _cart!.items.where((i) => i.id != item.id).toList(),
          );
        });
        await _loadCart();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메뉴 삭제에 실패했습니다')));
    }
  }

  List<TargetParticipantStatus> _participantsMissingMenus() {
    if (_cart == null || _participantStatuses.isEmpty) {
      return const <TargetParticipantStatus>[];
    }

    final Map<String, int> itemCountByUser = {};
    for (final item in _cart!.items) {
      final normalizedUserId = item.userId.trim();
      if (normalizedUserId.isEmpty) {
        continue;
      }
      itemCountByUser[normalizedUserId] =
          (itemCountByUser[normalizedUserId] ?? 0) + 1;
    }

    final List<TargetParticipantStatus> missing = [];
    for (final participant in _participantStatuses) {
      if (participant.isHost) {
        continue;
      }
      final userId = participant.userId.trim();
      if (userId.isEmpty) {
        continue;
      }
      if ((itemCountByUser[userId] ?? 0) == 0) {
        missing.add(participant);
      }
    }
    return missing;
  }

  bool _validateParticipantMenus() {
    logDebug(
      '참여자 메뉴 검증 시작: _participantStatuses.length=${_participantStatuses.length}',
    );

    final missing = _participantsMissingMenus();

    if (missing.isEmpty) {
      logDebug('모든 참여자가 메뉴를 담음 - 검증 통과');
      return true;
    }

    final names = missing
        .map(
          (participant) =>
              participant.nickname.isNotEmpty ? participant.nickname : '참여자',
        )
        .join(', ');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('아직 메뉴를 담지 않은 참여자: $names')));
    return false;
  }

  Future<void> _completeCart() async {
    logDebug('=== _completeCart 함수 시작 ===');

    if (_cart == null || !_validateParticipantMenus()) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문 완료'),
        content: const Text('주문을 완료하시겠습니까?\n완료 후 영수증이 공유됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('완료', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final response = await SharedCartApi.completeSharedCart(
        roomId: widget.roomId,
      );

      if (response['success'] == true) {
        final summaryData = _unwrapApiData(response['data']);
        final summary = summaryData != null
            ? SharedCartSummary.fromJson(summaryData)
            : null;

        if (!mounted) return;

        // 연결된 게시물 모집 상태를 '모집완료'로 변경
        if (widget.linkedPostId != null && widget.linkedPostId!.isNotEmpty) {
          try {
            final postResult = await PostApi.closeRecruitment(
              widget.linkedPostId!,
            );
          } catch (e) {
            logDebug('Post close request failed (${e.runtimeType})');
            // 게시물 상태 변경 실패하더라도 주문 완료는 계속 진행
          }
        } else {
          logDebug('linkedPostId가 null이거나 비어있어 게시물 상태 변경 건너뜀');
        }


        // 성공 팝업 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주문이 완료되었습니다! 영수증이 공유됩니다.'),
            backgroundColor: Color(0xFF81C784),
            duration: Duration(seconds: 2),
          ),
        );

        // 잠시 후 채팅방으로 돌아가기
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.pop(context, summary ?? true); // 채팅방으로 돌아가기
      } else {
        // API 실패 응답 처리
        final message = response['message']?.toString() ?? '주문 완료에 실패했습니다.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문 완료에 실패했습니다')));
    }
  }

  @override
  void dispose() {
    _stopCartPolling();
    super.dispose();
  }

  void _startCartPolling() {
    if (!mounted || _cart == null || _cart!.isCompleted) return;
    _stopCartPolling();
    _cartPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollCartUpdates(),
    );
  }

  void _stopCartPolling() {
    _cartPollTimer?.cancel();
    _cartPollTimer = null;
  }

  Future<void> _pollCartUpdates() async {
    if (!mounted || _cart == null || _cart!.isCompleted) {
      _stopCartPolling();
      return;
    }
    try {
      final response = await SharedCartApi.getSharedCart(roomId: widget.roomId);
      if (response['success'] != true) return;
      final data = _unwrapApiData(response['data']);
      if (data == null) return;
      final latestCart = SharedCart.fromJson(data);
      if (_cartItemsEqual(_cart!, latestCart)) return;
      if (!mounted) return;
      final isCompleted = latestCart.isCompleted;
      setState(() {
        _cart = latestCart;
        _isReadOnly = isCompleted;
        _needsActivation = !latestCart.isActive && !isCompleted;
      });
      if (isCompleted) {
        _stopCartPolling();
      }
    } catch (e) {
      logDebug('Shared cart refresh failed (${e.runtimeType})');
    }
  }

  bool _cartItemsEqual(SharedCart current, SharedCart remote) {
    if (current.items.length != remote.items.length) return false;
    final sortedCurrent = [...current.items]
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedRemote = [...remote.items]
      ..sort((a, b) => a.id.compareTo(b.id));
    for (var i = 0; i < sortedCurrent.length; i++) {
      if (_itemFingerprint(sortedCurrent[i]) !=
          _itemFingerprint(sortedRemote[i])) {
        return false;
      }
    }
    return true;
  }

  String _itemFingerprint(CartMenuItem item) =>
      '${item.id}|${item.name}|${item.price}|${item.userId}|${item.userNickname}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '공용 장바구니',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF81C784)),
            )
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _cart == null
          ? const Center(child: Text('장바구니가 비어있습니다'))
          : _buildCartContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildCartContent() {
    if (_cart!.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              '장바구니가 비어있어요',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (!_isReadOnly)
              if (_cart!.isActive)
                Text(
                  '함께 먹고 싶은 메뉴를 추가해보세요.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
            if (_needsActivation)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  widget.isHost
                      ? '주문을 시작하면 메뉴를 추가할 수 있어요.'
                      : '방장이 주문을 시작할 때까지 기다려 주세요.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
      );
    }

    // 사용자별로 그룹화
    final Map<String, List<CartMenuItem>> groupedItems = {};
    for (final item in _cart!.items) {
      if (!groupedItems.containsKey(item.userNickname)) {
        groupedItems[item.userNickname] = [];
      }
      groupedItems[item.userNickname]!.add(item);
    }

    return Column(
      children: [
        if (_isReadOnly)
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFE8F5E9),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF81C784)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '주문이 완료되어 영수증이 공유되었습니다.',
                    style: TextStyle(color: Colors.grey[800], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        if (_needsActivation)
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFFF9E7),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Color(0xFFFFB74D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isHost
                        ? '주문을 아직 시작하지 않았습니다. 메뉴 추가 전 주문을 시작해주세요.'
                        : '방장이 주문을 시작하면 메뉴를 추가할 수 있습니다.',
                    style: TextStyle(color: Colors.grey[800], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedItems.length,
            itemBuilder: (context, index) {
              final nickname = groupedItems.keys.elementAt(index);
              final items = groupedItems[nickname]!;
              final subtotal = items.fold(0, (sum, item) => sum + item.price);

              return _buildUserSection(nickname, items, subtotal);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserSection(
    String nickname,
    List<CartMenuItem> items,
    int subtotal,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${subtotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF81C784),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map((item) => _buildMenuItem(item)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(CartMenuItem item) {
    final bool cartActive = _cart?.isActive == true;
    final bool canEdit =
        cartActive && (widget.isHost || item.userId == _currentUserId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (canEdit)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: Colors.grey[600],
                  onPressed: () => _editMenuItem(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  color: Colors.grey[600],
                  onPressed: () => _deleteMenuItem(item),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_cart == null) return const SizedBox.shrink();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_cart?.isActive == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addMenuItem,
                    icon: const Icon(Icons.add),
                    label: const Text('메뉴 추가하기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF81C784),
                      side: const BorderSide(color: Color(0xFF81C784)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            if (_needsActivation)
              _buildActivationButton()
            else if (widget.isHost && !_isReadOnly)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cart!.items.isEmpty ? null : _completeCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C784),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: const Text(
                    '완료',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _isReadOnly
                        ? '주문 완료'
                        : _needsActivation
                        ? '방장이 주문을 시작하면 메뉴를 추가할 수 있어요'
                        : '방장이 주문을 완료할 수 있습니다',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF81C784),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivationButton() {
    if (_isReadOnly) {
      return const SizedBox.shrink();
    }
    if (!widget.isHost) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '방장이 주문을 시작하면 메뉴를 담을 수 있습니다',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFFFB74D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isActivatingCart ? null : _activateCart,
        icon: _isActivatingCart
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(
          _isActivatingCart ? '주문 시작 중...' : '주문 시작하기',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81C784),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
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
}

class _AddMenuDialog extends StatefulWidget {
  final String? initialName;
  final int? initialPrice;
  final bool isEdit;

  const _AddMenuDialog({
    this.initialName,
    this.initialPrice,
    this.isEdit = false,
  });

  @override
  State<_AddMenuDialog> createState() => _AddMenuDialogState();
}

class _AddMenuDialogState extends State<_AddMenuDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _priceController = TextEditingController(
      text: widget.initialPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메뉴명을 입력해주세요')));
      return;
    }

    final price = int.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 가격을 입력해주세요')));
      return;
    }

    Navigator.pop(context, {'name': name, 'price': price});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? '메뉴 수정' : '메뉴 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '메뉴명',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: '가격',
              border: OutlineInputBorder(),
              suffixText: '원',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.isEdit ? '수정' : '추가',
            style: const TextStyle(color: Color(0xFF81C784)),
          ),
        ),
      ],
    );
  }
}
