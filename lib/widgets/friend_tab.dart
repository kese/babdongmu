import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/friend_post_data.dart';
import '../models/chat_list_data.dart';
import '../pages/chat_room_page.dart';
import '../pages/post_detail_page.dart';
import '../utils/url_utils.dart';

class FriendTab extends StatefulWidget {
  const FriendTab({super.key});

  @override
  State<FriendTab> createState() => FriendTabState();
}

// with AutomaticKeepAliveClientMixin: 다른 탭으로 이동해도 위젯의 상태를 메모리에 계속 유지시켜주는 Mixin
// (탭을 다시 방문했을 때 스크롤 위치나 데이터가 초기화되지 않음)
class FriendTabState extends State<FriendTab>
    with AutomaticKeepAliveClientMixin {
  // 헬퍼함수
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
        radius: 25,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, color: Colors.grey[600], size: 28),
      );
    }

    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey[300],
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {},
    );
  }

  // 서버로부터 받아온 게시글 목록을 저장하는 리스트
  List<FriendPost> posts = [];
  // 데이터 로딩 여부 변수
  bool isLoading = true;
  // 데이터 로딩 중 에러가 발생했을때 에러 메세지 저장 변수
  String? errorMessage;

  @override
  bool get wantKeepAlive => true; // 탭 상태를 유지하려면 true로 설정

  @override
  // 위젯이 처음 생성될때 딱 한번 호출되는 메서드로 게시글 데이터를 불러옴
  void initState() {
    super.initState();
    _fetchPosts();
  }

  void loadPosts() {
    _fetchPosts();
  }

  // ApiService를 사용하여 서버로부터 게시글 목록을 가져오는 메서드
  Future<void> _fetchPosts() async {
    await ApiService.fetchWithState<FriendPost>(
      apiCall: PostApi.getFriendPosts,
      setLoading: (loading) {
        if (mounted) setState(() => isLoading = loading);
      },
      onSuccess: (data) {
        if (mounted) {
          setState(() {
            posts = data;
            errorMessage = null; // 성공시 이전 에러 메세지 초기화
          });
        }
      },
      onError: (message) {
        if (mounted) setState(() => errorMessage = message);
      },
      fromJson: FriendPost.fromJson,
    );
  }

  // 채팅방으로 이동하는 메서드
  Future<void> _navigateToChatRoom(String chatRoomId, FriendPost post) async {
    final chatRoom = ChatRoomList(
      id: chatRoomId,
      postTitle: post.title,
      postType: '주문중',
      roomType: 'meet',
      location: post.meetingPlace,
      lastMessage: '채팅방이 생성되었습니다',
      lastMessageTime: '방금',
      currentPeople: post.currentPeople,
      maxPeople: post.maxPeople,
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
    // 탭 상태 유지를 위해 super.build 호출
    super.build(context);

    if (isLoading) {
      // 로딩 중: 화면 중앙에 로딩 인디케이터 표시
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF81C784)),
      );
    }

    if (errorMessage != null) {
      // 에러 발생: 에러 메세지와 '다시 시도' 버튼 표시
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81C784),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (posts.isEmpty) {
      // 게시글 하나도 없음: '게시글 없음' 메시지 표시
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '아직 게시글이 없습니다',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      // 성공적으로 데이터 불러옴: 게시글 목록 표시
      onRefresh: _fetchPosts, // 화면을 아래로 당겨 새로고침하는 기능
      color: const Color(0xFF81C784),
      // 화면에 보이는만큼만 리스트를 보여줌
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildFriendCard(post),
          );
        },
      ),
    );
  }

  // '친구 찾기' 게시글 카드 UI 그리는 메서드
  Widget _buildFriendCard(FriendPost post) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFCDE6CE), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildProfileAvatar(post.userProfileImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        post.date,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: post.isRecruiting
                        ? const Color(0xFFE0F7F4)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    post.isRecruiting ? '모집중' : '모집완료',
                    style: TextStyle(
                      color: post.isRecruiting
                          ? const Color(0xFF81C784)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // 음식점 정보 (강조)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    size: 14,
                    color: Color(0xFFFF6B35),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  post.storeName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 만날 장소 정보
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81C784).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 14,
                    color: const Color(0xFF81C784),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    post.meetingPlace,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${post.currentPeople}/${post.maxPeople}명',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: post.maxPeople > 0
                  ? post.currentPeople / post.maxPeople
                  : 0,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF81C784),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _deadlineFormat(post.deadline),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: post.isRecruiting
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailPage(
                              postId: post.id,
                              postType: 'friend',
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: post.isRecruiting
                      ? const Color(0xFF81C784)
                      : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  post.isRecruiting ? '참여하기' : '모집 완료',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: post.isRecruiting ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
