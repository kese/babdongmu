import 'package:flutter/material.dart';
import '../models/delivery_post_data.dart';
import '../models/friend_post_data.dart';
import '../services/post_api.dart';
import '../utils/url_utils.dart';
import 'chat_room_page.dart';
import '../models/chat_list_data.dart';

/// 게시물 상세 화면
class PostDetailPage extends StatelessWidget {
  final String postId;
  final String postType; // 'delivery' or 'friend'
  final Map<String, dynamic>? initialData;

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.postType,
    this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '게시물 상세',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: PostApi.getPost(postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF81C784)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    '게시물을 불러올 수 없습니다',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81C784),
                    ),
                    child: const Text('돌아가기'),
                  ),
                ],
              ),
            );
          }

          final result = snapshot.data!;
          if (result['success'] != true) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    result['message'] ?? '게시물을 불러올 수 없습니다',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81C784),
                    ),
                    child: const Text('돌아가기'),
                  ),
                ],
              ),
            );
          }

          final postData = result['data'];
          if (postType == 'delivery') {
            final post = DeliveryPost.fromJson(postData);
            return _DeliveryPostDetail(post: post);
          } else {
            final post = FriendPost.fromJson(postData);
            return _FriendPostDetail(post: post);
          }
        },
      ),
    );
  }
}

/// 배달 게시물 상세 화면
class _DeliveryPostDetail extends StatefulWidget {
  final DeliveryPost post;

  const _DeliveryPostDetail({required this.post});

  @override
  State<_DeliveryPostDetail> createState() => _DeliveryPostDetailState();
}

class _DeliveryPostDetailState extends State<_DeliveryPostDetail> {
  bool _isJoining = false;

  String _deadlineFormat(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(deadline.year, deadline.month, deadline.day);

    String day;
    if (dDay == today) {
      day = '오늘';
    } else if (dDay == today.add(const Duration(days: 1))) {
      day = '내일';
    } else {
      day = '${deadline.month}/${deadline.day}';
    }

    final twentyfourH = deadline.hour;
    final minute = deadline.minute;

    String amPm = twentyfourH < 12 ? '오전' : '오후';

    int twelveH = twentyfourH % 12;
    if (twelveH == 0) {
      twelveH = 12;
    }

    String time;
    if (minute == 0) {
      time = '$twelveH시';
    } else {
      time = '$twelveH시 $minute분';
    }

    return '$day $amPm $time';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  // 프로필 이미지 아바타 위젯 생성
  Widget _buildProfileAvatar(String? profileImageUrl) {
    final imageUrl = UrlUtils.getImageUrl(profileImageUrl);

    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, color: Colors.white, size: 28),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[300],
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {},
    );
  }

  Future<void> _showJoinDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '게시글 참여',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '밥동무는 매칭만 중개합니다. \n 약속 불참, 취소, 지각 등 \n 발생하는 모든 문제의 책임은 \n사용자 본인에게 있습니다.',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('이 게시글에 참여하시겠습니까?', style: TextStyle(fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81C784),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('참가하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _handleJoin();
    }
  }

  Future<void> _handleJoin() async {
    setState(() => _isJoining = true);

    try {
      final result = await PostApi.joinDeliveryPost(widget.post.id);

      if (!mounted) return;

      if (result['success']) {
        final data = result['data'] ?? {};
        final chatRoomId =
            data['chat_room_id'] ?? data['chatRoomId'] ?? data['roomId'];

        if (chatRoomId != null) {
          _navigateToChatRoom(chatRoomId);
        } else {
          // 참여는 성공했지만 채팅방 ID가 없는 경우 - 성공 메시지 표시
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('참여 완료! 채팅방 목록을 확인해주세요'),
                backgroundColor: const Color(0xFF81C784),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '참여에 실패했습니다'),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('요청을 처리하지 못했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _navigateToChatRoom(String chatRoomId) async {
    final chatRoom = ChatRoomList(
      id: chatRoomId,
      postTitle: widget.post.title,
      postType: '배달중',
      roomType: 'delivery',
      location: widget.post.deliveryPlace,
      lastMessage: '채팅방이 생성되었습니다',
      lastMessageTime: '방금',
      currentPeople: widget.post.currentPeople,
      maxPeople: widget.post.maxPeople,
      hasUnread: false,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatRoomPage(chatRoom: chatRoom, deliveryPost: widget.post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 정보 및 모집 상태
            Row(
              children: [
                _buildProfileAvatar(widget.post.userProfileImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.post.userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.post.isRecruiting
                        ? const Color(0xFFE0F7F4)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.post.isRecruiting ? '모집중' : '모집완료',
                    style: TextStyle(
                      color: widget.post.isRecruiting
                          ? const Color(0xFF81C784)
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 제목
            Text(
              widget.post.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),

            // 작성 날짜
            Text(
              widget.post.date,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 28),

            // 음식점
            _buildInfoRow('음식점', widget.post.storeName),
            const SizedBox(height: 16),

            // 배달 장소
            _buildInfoRow('배달 장소', widget.post.deliveryPlace),
            const SizedBox(height: 16),

            // 최소 주문 금액
            _buildInfoRow(
              '최소 주문 금액',
              '${_formatNumber(widget.post.targetPrice)}원',
            ),
            const SizedBox(height: 16),

            // 최대 인원
            _buildInfoRow(
              '최대 인원',
              '${widget.post.maxPeople}명 (현재 ${widget.post.currentPeople}명 참여)',
            ),
            const SizedBox(height: 16),

            // 배달비
            _buildInfoRow(
              '배달비',
              '${_formatNumber(widget.post.deliveryFee)}원 (인당 ${_formatNumber(widget.post.feePerPerson)}원)',
            ),
            const SizedBox(height: 16),

            // 마감 시간
            _buildInfoRow('마감 시간', _deadlineFormat(widget.post.deadline)),

            // 상세 내용 (있을 경우에만 표시)
            if (widget.post.details != null &&
                widget.post.details!.trim().isNotEmpty) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                widget.post.details!,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 40),

            // 참여하기 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: widget.post.isRecruiting && !_isJoining
                    ? _showJoinDialog
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.post.isRecruiting
                      ? const Color(0xFF81C784)
                      : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.post.isRecruiting ? '참여하기' : '모집 완료',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: widget.post.isRecruiting
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// 친구 구하기 게시물 상세 화면
class _FriendPostDetail extends StatefulWidget {
  final FriendPost post;

  const _FriendPostDetail({required this.post});

  @override
  State<_FriendPostDetail> createState() => _FriendPostDetailState();
}

class _FriendPostDetailState extends State<_FriendPostDetail> {
  bool _isJoining = false;

  String _deadlineFormat(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(deadline.year, deadline.month, deadline.day);

    String day;
    if (dDay == today) {
      day = '오늘';
    } else if (dDay == today.add(const Duration(days: 1))) {
      day = '내일';
    } else {
      day = '${deadline.month}/${deadline.day}';
    }

    final twentyfourH = deadline.hour;
    final minute = deadline.minute;

    String amPm = twentyfourH < 12 ? '오전' : '오후';

    int twelveH = twentyfourH % 12;
    if (twelveH == 0) {
      twelveH = 12;
    }

    String time;
    if (minute == 0) {
      time = '$twelveH시';
    } else {
      time = '$twelveH시 $minute분';
    }

    return '$day $amPm $time';
  }

  // 프로필 이미지 아바타 위젯 생성
  Widget _buildProfileAvatar(String? profileImageUrl) {
    final imageUrl = UrlUtils.getImageUrl(profileImageUrl);

    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, color: Colors.white, size: 28),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[300],
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {},
    );
  }

  Future<void> _showJoinDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '게시글 참여',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text('이 게시글에 참여하시겠습니까?', style: TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81C784),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('참가하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _handleJoin();
    }
  }

  Future<void> _handleJoin() async {
    setState(() => _isJoining = true);

    try {
      final result = await PostApi.joinFriendPost(widget.post.id);

      if (!mounted) return;

      if (result['success']) {
        final data = result['data'] ?? {};
        final chatRoomId =
            data['chat_room_id'] ?? data['chatRoomId'] ?? data['roomId'];

        if (chatRoomId != null) {
          _navigateToChatRoom(chatRoomId);
        } else {
          // 참여는 성공했지만 채팅방 ID가 없는 경우 - 성공 메시지 표시
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('참여 완료! 채팅방 목록을 확인해주세요'),
                backgroundColor: const Color(0xFF81C784),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '참여에 실패했습니다'),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('요청을 처리하지 못했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _navigateToChatRoom(String chatRoomId) async {
    final chatRoom = ChatRoomList(
      id: chatRoomId,
      postTitle: widget.post.title,
      postType: '주문중',
      roomType: 'meet',
      location: widget.post.meetingPlace,
      lastMessage: '채팅방이 생성되었습니다',
      lastMessageTime: '방금',
      currentPeople: widget.post.currentPeople,
      maxPeople: widget.post.maxPeople,
      hasUnread: false,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatRoomPage(chatRoom: chatRoom)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 정보 및 모집 상태
            Row(
              children: [
                _buildProfileAvatar(widget.post.userProfileImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.post.userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.post.isRecruiting
                        ? const Color(0xFFE0F7F4)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.post.isRecruiting ? '모집중' : '모집완료',
                    style: TextStyle(
                      color: widget.post.isRecruiting
                          ? const Color(0xFF81C784)
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 제목
            Text(
              widget.post.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),

            // 작성 날짜
            Text(
              widget.post.date,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 28),

            // 음식점
            _buildInfoRow('음식점', widget.post.storeName),
            const SizedBox(height: 16),

            // 만날 장소
            _buildInfoRow('만날 장소', widget.post.meetingPlace),
            const SizedBox(height: 16),

            // 최대 인원
            _buildInfoRow(
              '최대 인원',
              '${widget.post.maxPeople}명 (현재 ${widget.post.currentPeople}명 참여)',
            ),
            const SizedBox(height: 16),

            // 마감 시간
            _buildInfoRow('마감 시간', _deadlineFormat(widget.post.deadline)),

            // 상세 내용 (있을 경우에만 표시)
            if (widget.post.details != null &&
                widget.post.details!.trim().isNotEmpty) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                widget.post.details!,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 40),

            // 참여하기 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: widget.post.isRecruiting && !_isJoining
                    ? _showJoinDialog
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.post.isRecruiting
                      ? const Color(0xFF81C784)
                      : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.post.isRecruiting ? '참여하기' : '모집 완료',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: widget.post.isRecruiting
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
