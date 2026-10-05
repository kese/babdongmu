import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/delivery_post_data.dart';
import '../models/chat_list_data.dart';
import '../pages/chat_room_page.dart';
import '../pages/post_detail_page.dart';
import '../utils/url_utils.dart';

class DeliveryTab extends StatefulWidget {
  const DeliveryTab({super.key});

  @override
  State<DeliveryTab> createState() => DeliveryTabState();
}

// with AutomaticKeepAliveClientMixin: 다른 탭으로 이동해도 위젯의 상태를 메모리에 계속 유지시켜주는 Mixin
// (탭을 다시 방문했을 때 스크롤 위치나 데이터가 초기화되지 않음)
class DeliveryTabState extends State<DeliveryTab>
    with AutomaticKeepAliveClientMixin {
  //헬퍼함수
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
      // 이미지가 없는 경우 기본 아바타
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, color: Colors.grey[600], size: 28),
      );
    }

    // 이미지가 있는 경우 네트워크 이미지 표시
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey[300],
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {
        // 이미지 로드 실패 시 무시 (기본 배경색 유지)
      },
    );
  }

  // 서버로부터 받아온 게시글 목록을 저장하는 리스트
  List<DeliveryPost> posts = [];
  // 데이터 로딩 여부 변수
  bool isLoading = true;
  // 데이터 로딩 중 에러가 발생했을때 에러 메세지 저장 변수
  String? errorMessage;

  @override
  // true: 탭 상태 항상 유지
  bool get wantKeepAlive => true;

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
    await ApiService.fetchWithState<DeliveryPost>(
      apiCall: PostApi.getDeliveryPosts,
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
      fromJson: DeliveryPost.fromJson,
    );
  }

  // 채팅방으로 이동하는 메서드
  Future<void> _navigateToChatRoom(String chatRoomId, DeliveryPost post) async {
    final chatRoom = ChatRoomList(
      id: chatRoomId,
      postTitle: post.title,
      postType: '배달중',
      roomType: 'delivery',
      location: post.deliveryPlace,
      lastMessage: '채팅방이 생성되었습니다',
      lastMessageTime: '방금',
      currentPeople: post.currentPeople,
      maxPeople: post.maxPeople,
      hasUnread: false,
    );

    ApiService.cacheDeliveryFeeInfo(
      roomId: chatRoomId,
      deliveryFee: post.deliveryFee,
      deliveryFeePerPerson: post.feePerPerson,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatRoomPage(chatRoom: chatRoom, deliveryPost: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 탭 상태 유지를 위해 super.build 호출
    super.build(context);

    // 로딩 중: 화면 중앙에 로딩 인디케이터 표시
    if (isLoading) {
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
      child: ListView.builder(
        // 화면에 보이는만큼만 리스트를 보여줌
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDeliveryCard(post),
          );
        },
      ),
    );
  }

  // 게시글 카드 UI를 그리는 메서드
  Widget _buildDeliveryCard(DeliveryPost post) {
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
            // 배달 장소 정보
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
                    _formatDeliveryAddress(post.deliveryPlace),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '목표 금액: ${_formatNumber(post.targetPrice)}원',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '배달비 ${_formatNumber(post.deliveryFee)}원 (인당 ${_formatNumber(post.feePerPerson)}원)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
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
                              postType: 'delivery',
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

  String _formatNumber(int number) {
    // 숫자를 세자리 마다 콤마(,)로 구분하는 포맷팅 함수
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
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
      // 도로명주소 패턴: 시/도 + 시/군/구 + 동/면/읍/로/길 + 번지
      // 상세내용은 보통 영문 또는 숫자+동/호 등으로 끝남
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
  /// 예: "충청북도 충주시 대소원면 대학촌1길 27 wonroom" -> "wonroom"
  String? _extractDetailFromAddress(String address) {
    final parts = address.trim().split(' ');
    if (parts.isEmpty) return null;

    // 뒤에서부터 상세내용 찾기
    // 도로명주소 패턴이 아닌 부분을 상세내용으로 간주
    final detailParts = <String>[];

    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];

      // 도로명주소 구성요소 패턴 (시/도, 시/군/구, 동/면/읍/로/길, 번지)
      final isAddressPart = RegExp(
        r'^(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주|충청북도|충청남도|전라북도|전라남도|경상북도|경상남도)' // 시/도
        r'|.+(시|군|구)$' // 시/군/구
        r'|.+(동|면|읍|리|로|길)$' // 동/면/읍/리/로/길
        r'|^\d+(-\d+)?$', // 번지 (숫자 또는 숫자-숫자)
      ).hasMatch(part);

      if (isAddressPart) {
        // 도로명주소 부분을 만나면 중단
        break;
      }

      // 상세내용 추가 (역순이므로 앞에 삽입)
      detailParts.insert(0, part);
    }

    if (detailParts.isEmpty) return null;

    return detailParts.join(' ');
  }
}
