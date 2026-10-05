import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:delivery/utils/logging.dart';
import '../services/api.dart';
import '../models/user_data.dart';
import 'edit_profile_page.dart';

/// 마이페이지 화면

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  User? user; // API에서 받아올 사용자 정보
  int userPoints = 0; // API에서 받아올 포인트
  bool _isLoading = false;
  String _displayNickname = '사용자';

  // 배달비 절약 통계 (API에서 가져올 데이터)
  int totalOrders = 0; // 총 주문 횟수
  int totalDeliveryFeeSaved = 0; // 절약한 배달비 (원)
  int totalDeliveryFeePaid = 0; // 실제 낸 배달비 (원)
  int originalDeliveryFee = 0; // 원래 내야 했던 배달비 (원)

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 사용자 정보 불러오기 (API 호출만)
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final storedNickname = await ApiService.getUserNickname();

      // 프로필 정보 가져오기
      final profileResult = await UserApi.getUserProfile();
      if (profileResult['success'] == true) {
        final fetchedUser = User.fromJson(profileResult['data']);
        setState(() {
          user = fetchedUser;
          _displayNickname = fetchedUser.nickname.isNotEmpty
              ? fetchedUser.nickname
              : (storedNickname ?? '사용자');
        });
      } else if (storedNickname != null && mounted) {
        setState(() {
          _displayNickname = storedNickname;
        });
      }

      // 포인트 정보 가져오기
      final pointsResult = await UserApi.getUserPoints();
      if (pointsResult['success'] == true) {
        setState(() {
          userPoints = pointsResult['data']['points'] ?? 0;
        });
      }

      // 배달비 절약 통계 가져오기
      final statsResult = await UserApi.getDeliveryStats();
      if (statsResult['success'] == true) {
        final rawData = statsResult['data'];
        if (rawData is Map<String, dynamic>) {
          setState(() {
            totalOrders = _parseInt(
              rawData['total_orders'] ?? rawData['totalOrders'],
            );
            totalDeliveryFeeSaved = _parseInt(
              rawData['total_delivery_fee_saved'] ??
                  rawData['totalDeliveryFeeSaved'],
            );
            totalDeliveryFeePaid = _parseInt(
              rawData['total_delivery_fee_paid'] ??
                  rawData['totalDeliveryFeePaid'],
            );
            originalDeliveryFee = _parseInt(
              rawData['original_delivery_fee'] ??
                  rawData['originalDeliveryFee'],
            );
          });
        }
      }
    } catch (e) {
      logDebug('User profile load failed (${e.runtimeType})');
      final storedNickname = await ApiService.getUserNickname();
      if (storedNickname != null && mounted) {
        setState(() {
          _displayNickname = storedNickname;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF81C784)),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  _buildProfileSection(),
                  const SizedBox(height: 20),
                  _buildPointsSection(), // 포인트 섹션 유지
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  _buildMenuList(),
                  const SizedBox(height: 40),
                  _buildLogoutButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileSection() {
    final nickname = _resolvedNickname;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildProfileAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((user?.email ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      user!.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildSavingsChart(),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final profileImage = _resolveProfileImage();

    return CircleAvatar(
      radius: 40,
      backgroundColor: const Color(0xFFE0B896),
      backgroundImage: profileImage,
      child: profileImage == null
          ? Icon(
              Icons.person,
              size: 40,
              color: Colors.white.withValues(alpha: 0.8),
            )
          : null,
    );
  }

  String get _resolvedNickname {
    final apiNickname = user?.nickname ?? '';
    if (apiNickname.trim().isNotEmpty) {
      return apiNickname.trim();
    }
    return _displayNickname;
  }

  ImageProvider<Object>? _resolveProfileImage() {
    final imageUrl = user?.profileImage;
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }

    final trimmed = imageUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    return NetworkImage('${ApiService.baseUrl}/$trimmed');
  }

  // 배달비 절약 원형 그래프
  Widget _buildSavingsChart() {
    final savingsPercentage = originalDeliveryFee > 0
        ? (totalDeliveryFeeSaved / originalDeliveryFee * 100).round()
        : 0;

    return GestureDetector(
      onTap: _showSavingsDetail,
      child: SizedBox(
        width: 100,
        height: 100,
        child: CustomPaint(
          painter: _DonutChartPainter(
            paidAmount: totalDeliveryFeePaid,
            savedAmount: totalDeliveryFeeSaved,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '배달비',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF43A047),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$savingsPercentage%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF81C784),
                    height: 1.2, // 줄 간격 조정
                  ),
                ),
                const Text(
                  '절약',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF43A047),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 배달비 절약 상세 정보 다이얼로그
  void _showSavingsDetail() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '배달비 절약 현황',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                '원래 배달비',
                originalDeliveryFee,
                const Color(0xFF79BA7B),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                '실제 낸 배달비',
                totalDeliveryFeePaid,
                const Color(0xFFEBF5EC),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                '절약한 배달비',
                totalDeliveryFeeSaved,
                const Color(0xFF81C784),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '확인',
                style: TextStyle(color: Color(0xFF81C784)),
              ),
            ),
          ],
        );
      },
    );
  }

  // 배달비 상세 정보 행
  Widget _buildDetailRow(String label, int amount, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        Text(
          '${_formatNumber(amount)}원',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPointsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '나의 포인트',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatNumber(userPoints)} P',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPointButton(
                  icon: Icons.credit_card,
                  label: '충전하기',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('충전하기 기능 준비중입니다')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPointButton(
                  icon: Icons.account_balance_wallet,
                  label: '출금하기',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('출금하기 기능 준비중입니다')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE8F5E9),
        foregroundColor: const Color(0xFF81C784),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.edit,
            iconColor: const Color(0xFF81C784),
            title: '내 정보 수정',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfilePage(),
                ),
              );
              // 페이지에서 돌아온 후 사용자 정보 다시 불러오기
              _loadUserData();
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.campaign,
            iconColor: const Color(0xFF81C784),
            title: '공지사항',
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('공지사항 페이지 준비중입니다')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextButton(
        onPressed: _handleLogout,
        style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
        child: const Text(
          '로그아웃',
          style: TextStyle(fontSize: 14, decoration: TextDecoration.underline),
        ),
      ),
    );
  }

  // 로그아웃 처리
  Future<void> _handleLogout() async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '확인',
                style: TextStyle(color: Color(0xFF81C784)),
              ),
            ),
          ],
        );
      },
    );

    // 사용자가 확인을 눌렀을 때만 실행
    if (confirmed == true) {
      final result = await UserApi.logout();

      if (!mounted) return;

      if (result['success'] == true) {
        // 로그인 화면으로 이동 (모든 이전 화면 제거)
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        // 로그아웃 실패 시 에러 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '로그아웃에 실패했습니다')),
        );
      }
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

// 배달비 절약 도넛 차트 페인터
class _DonutChartPainter extends CustomPainter {
  final int paidAmount; // 실제 낸 배달비
  final int savedAmount; // 절약한 배달비

  _DonutChartPainter({required this.paidAmount, required this.savedAmount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;

    // 전체 금액
    final total = paidAmount + savedAmount;
    final clampTotal = total == 0 ? 1 : total;

    // 비율 계산
    final paidRatio = total == 0 ? 0 : paidAmount / clampTotal;
    final savedRatio = total == 0 ? 0 : savedAmount / clampTotal;

    // 배경 원 (회색)
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    // 실제 낸 배달비
    final paidPaint = Paint()
      ..color = const Color(0xFFEBF5EC).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paidSweepAngle = 2 * math.pi * paidRatio;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2, // -90도 (12시 방향부터 시작)
      paidSweepAngle,
      false,
      paidPaint,
    );

    // 원래 배달비
    final savedPaint = Paint()
      ..color = const Color(0xFF79BA7B).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final savedSweepAngle = 2 * math.pi * savedRatio;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2 + paidSweepAngle, // 실제 낸 배달비가 끝난 위치부터
      savedSweepAngle,
      false,
      savedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
