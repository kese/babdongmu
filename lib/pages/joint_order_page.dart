import 'dart:async';

import 'package:delivery/models/chat_list_data.dart';
import 'package:delivery/models/joint_order_match_data.dart';
import 'package:delivery/pages/chat_room_page.dart';
import 'package:delivery/services/chat_api.dart';
import 'package:delivery/services/joint_order_api.dart';
import 'package:delivery/services/post_api.dart';
import 'package:delivery/utils/logging.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class JointOrderPage extends StatefulWidget {
  final VoidCallback? onNavigateToChat;

  const JointOrderPage({super.key, this.onNavigateToChat});

  @override
  State<JointOrderPage> createState() => _JointOrderPageState();
}

class _JointOrderPageState extends State<JointOrderPage> {
  bool _isLoading = false;
  bool _isMatching = false;
  bool _hasPendingRequest = false; // 중복 요청 방지를 위한 상태
  String? _userPostId;
  String? _storeName;
  String? _deliveryPlace;
  int? _deliveryFee;
  List<MatchablePost> _matchablePosts = [];
  String? _currentRequestId;
  Timer? _statusCheckTimer;
  int _remainingSeconds = 300; // 5분 타임아웃
  int _acceptedCount = 0; // 수락한 인원 수
  int _totalTargetCount = 0; // 요청한 총 인원 수
  Map<String, dynamic>? _latestPostDetail;
  Map<String, dynamic>? _latestChatRoomDetail;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  /// 매칭 시작 버튼 클릭
  Future<void> _startMatching() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 사용자의 게시글 정보 확인
      final userPostResult = await JointOrderApi.getUserPost();

      if (userPostResult['success'] != true) {
        if (mounted) {
          _showErrorDialog(userPostResult['message'] ?? '매칭 가능한 게시글이 없습니다.');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userPost = userPostResult['data'];
      _userPostId = userPost['id']?.toString();
      _storeName = userPost['store_name'] ?? userPost['storeName'];
      _deliveryPlace = userPost['delivery_place'] ?? userPost['deliveryPlace'];
      _deliveryFee = userPost['delivery_fee'] ?? userPost['deliveryFee'] ?? 0;

      // 서버에서 내려준 locationName (POI 명칭) 추출
      final locationName =
          (userPost['location_name'] ?? userPost['locationName'])
              ?.toString()
              .trim();


      // 2. 주소 유효성 검사 (방어 로직)
      if (_deliveryPlace == null ||
          _deliveryPlace!.isEmpty ||
          _deliveryPlace == '주소 미입력') {
        if (mounted) {
          _showErrorDialog('배달 장소가 설정되지 않았습니다. 게시글을 먼저 수정해주세요.');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }


      // 2. 매칭 가능한 게시글 목록 가져오기
      final matchableResult = await JointOrderApi.getMatchablePosts(
        storeName: _storeName!,
        deliveryPlace: _deliveryPlace!,
        deliveryFee: _deliveryFee ?? 0,
        locationName: locationName ?? '',
      );

      if (matchableResult['success'] != true) {
        if (mounted) {
          _showErrorDialog(
            matchableResult['message'] ?? '매칭 가능한 게시글을 찾을 수 없습니다.',
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final matchableData = matchableResult['data'] as List;

      if (matchableData.isEmpty) {
        if (mounted) {
          _showErrorDialog(
            '현재 $_storeName에서 $_deliveryPlace로 \n배달하는 다른 게시글이 없습니다.',
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _matchablePosts = matchableData
            .map((json) => MatchablePost.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      logDebug('Joint-order matching failed (${e.runtimeType})');
      if (mounted) {
        _showErrorDialog('매칭을 시작할 수 없습니다. 잠시 후 다시 시도해주세요.');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 합동 요청 버튼 클릭
  Future<void> _sendJointOrderRequest() async {
    final selectedPosts = _matchablePosts
        .where((post) => post.isSelected)
        .toList();

    if (selectedPosts.isEmpty) {
      _showErrorDialog('최소 1개 이상의 게시글을 선택해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final targetPostIds = selectedPosts.map((post) => post.id).toList();

      final result = await JointOrderApi.sendJointOrderRequest(
        requesterPostId: _userPostId!,
        targetPostIds: targetPostIds,
      );

      if (result['success'] == true) {
        _currentRequestId = result['data']['request_id'];

        setState(() {
          _isMatching = true;
          _hasPendingRequest = true; // 중복 요청 방지 상태 설정
          _isLoading = false;
        });

        // 5분 타이머 시작 및 주기적으로 상태 확인
        _startRequestStatusCheck();
      } else {
        if (mounted) {
          String errorMessage = result['message'] ?? '요청 전송에 실패했습니다.';

          // 400 에러 메시지 개선
          if (result['statusCode'] == 400) {
            errorMessage = '요청 형식이 올바르지 않습니다. 다시 시도해주세요.';
          } else if (result['statusCode'] == 401) {
            errorMessage = '로그인이 필요합니다.';
          } else if (result['statusCode'] == 403) {
            errorMessage = '권한이 없습니다.';
          } else if (result['statusCode'] == 404) {
            errorMessage = '요청을 처리할 수 없습니다.';
          } else if (result['statusCode'] == 500) {
            errorMessage = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
          }

          _showErrorDialog(errorMessage);
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      logDebug('Joint-order request failed (${e.runtimeType})');
      String errorMessage = '요청을 처리할 수 없습니다.';

      // 네트워크 오류 처리
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = '요청 시간이 초과되었습니다. 다시 시도해주세요.';
      }

      if (mounted) {
        _showErrorDialog(errorMessage);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 요청 상태 주기적으로 확인
  void _startRequestStatusCheck() {
    int elapsedSeconds = 0;
    const checkInterval = Duration(seconds: 1);
    const timeout = Duration(seconds: 300); // 5분 타임아웃
    int lastResponseCount = 0;

    // 남은 시간 및 카운터 초기화
    setState(() {
      _remainingSeconds = timeout.inSeconds;
      _acceptedCount = 0;
      _totalTargetCount = _matchablePosts.where((p) => p.isSelected).length;
    });

    _statusCheckTimer = Timer.periodic(checkInterval, (timer) async {
      elapsedSeconds += checkInterval.inSeconds;

      // 남은 시간 업데이트
      setState(() {
        _remainingSeconds = timeout.inSeconds - elapsedSeconds;
      });

      // 타임아웃 체크
      if (elapsedSeconds >= timeout.inSeconds) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isMatching = false;
          });
          _showMatchFailedDialog('요청 시간이 초과되었습니다.');
        }
        return;
      }

      // 요청 상태 확인
      try {
        if (_currentRequestId == null || _currentRequestId!.isEmpty) {
          logDebug('[JointOrder] 요청 ID가 없습니다.');
          timer.cancel();
          if (mounted) {
            setState(() {
              _isMatching = false;
            });
            _showMatchFailedDialog('요청 ID가 유효하지 않습니다.');
          }
          return;
        }

        final result = await JointOrderApi.checkRequestStatus(
          _currentRequestId!,
        );

        if (result['success'] == true && result['data'] != null) {
          final requestData = result['data'];

          // null 체크 강화
          final status = requestData['status'];
          final responses = List<Map<String, dynamic>>.from(
            requestData['responses'] ?? [],
          );
          final targetPostIds = List<String>.from(
            requestData['target_post_ids'] ?? [],
          );

          // 새로운 응답이 있는지 확인
          if (responses.length > lastResponseCount) {
            lastResponseCount = responses.length;

            // 새로운 응답 확인
            final latestResponse = responses.last;
            final accepted = latestResponse['accepted'] ?? false;
            final responderName = latestResponse['responder_name'] ?? '익명';

            if (mounted) {
              // 개별 응답 알림
              if (accepted) {
                setState(() {
                  _acceptedCount = responses
                      .where((r) => r['accepted'] == true)
                      .length;
                });
                _showAcceptedSnackBar(
                  responderName,
                  _acceptedCount,
                  targetPostIds.length,
                );
              } else {
                // 거절 시 즉시 매칭 실패 처리
                timer.cancel();
                setState(() {
                  _isMatching = false;
                  _hasPendingRequest = false;
                  _matchablePosts.clear(); // 초기 화면으로 돌아가기
                });
                _showMatchFailedDialog('$responderName님이 거절하여 매칭이 취소되었습니다.');
                return;
              }
            }
          }

          // 최종 상태 확인
          if (status == 'accepted') {
            timer.cancel();
            if (mounted) {
              // 매칭 성공 - 채팅방 생성
              await _createJointChatRoom(requestData);
            }
          } else if (status == 'rejected') {
            timer.cancel();
            if (mounted) {
              setState(() {
                _isMatching = false;
                _hasPendingRequest = false; // 중복 요청 방지 상태 해제
                _matchablePosts.clear(); // 초기 화면으로 돌아가기
              });
              _showMatchFailedDialog('일부 게시글 작성자가 거절하여 매칭에 실패했습니다.');
            }
          } else if (status == 'timeout') {
            timer.cancel();
            if (mounted) {
              setState(() {
                _isMatching = false;
                _hasPendingRequest = false; // 중복 요청 방지 상태 해제
                _matchablePosts.clear(); // 초기 화면으로 돌아가기
              });
              _showMatchFailedDialog('일부 게시글 작성자가 응답하지 않아 \n매칭이 취소되었습니다.');
            }
          }
        } else {
          // 요청 상태 확인 실패 처리
          logDebug('[JointOrder] Request status lookup failed');
          timer.cancel();
          if (mounted) {
            setState(() {
              _isMatching = false;
              _hasPendingRequest = false; // 중복 요청 방지 상태 해제
              _matchablePosts.clear(); // 초기 화면으로 돌아가기
            });
            _showMatchFailedDialog(result['message'] ?? '요청 상태를 확인할 수 없습니다.');
          }
        }
      } catch (e) {
        logDebug('Joint-order status lookup failed (${e.runtimeType})');
        timer.cancel();
        if (mounted) {
          setState(() {
            _isMatching = false;
            _hasPendingRequest = false; // 중복 요청 방지 상태 해제
            _matchablePosts.clear(); // 초기 화면으로 돌아가기
          });
          _showMatchFailedDialog('요청 상태 확인 중 오류가 발생했습니다.');
        }
      }
    });
  }

  /// 수락 알림 스낵바
  void _showAcceptedSnackBar(
    String responderName,
    int acceptedCount,
    int totalCount,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '수락 완료! $responderName님이 수락했습니다. ($acceptedCount/$totalCount)\n다른 사람의 수락을 기다리는 중...',
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: const Color(0xFF81C784),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 합동 채팅방 생성
  Future<void> _createJointChatRoom(Map<String, dynamic> requestData) async {
    try {
      final targetPostIds = List<String>.from(requestData['target_post_ids']);
      final allPostIds = [_userPostId!, ...targetPostIds];

      final result = await JointOrderApi.createJointChatRoom(
        requestId: _currentRequestId!,
        postIds: allPostIds,
      );

      if (result['success'] == true) {
        // 채팅방 ID 가져오기
        final chatRoomId = result['data']['chat_room_id'];
        await _refreshPostAndChatInfo(chatRoomId);
        if (!mounted) {
          return;
        }
        setState(() {
          _isMatching = false;
        });
        _showMatchSuccessDialog(chatRoomId);
      }
    } catch (e) {
      logDebug('Joint chat room creation failed (${e.runtimeType})');
      setState(() {
        _isMatching = false;
      });
      _showErrorDialog('채팅방 생성 중 오류가 발생했습니다.');
    }
  }

  /// 에러 다이얼로그
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/Failed attempt.json',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              repeat: false,
            ),
            const SizedBox(height: 10),
            const Text(
              '매칭 실패!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              message,
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

  /// 매칭 성공 다이얼로그 (채팅방 ID 포함)
  void _showMatchSuccessDialog(String? chatRoomId) async {
    final updatedInfoCard = _buildUpdatedGroupSummaryCard();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/Emoji Wink.json',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 5),
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
            if (updatedInfoCard != null) ...[
              const SizedBox(height: 20),
              updatedInfoCard,
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final dialogContext = context;

                if (chatRoomId != null) {
                  try {
                    final result = await JointOrderApi.getJointChatRoomInfo(
                      chatRoomId,
                    );

                    if (result['success'] == true) {
                      final chatRoomData = result['data'];
                      final chatRoom = ChatRoomList.fromJson(chatRoomData);

                      if (!mounted || !dialogContext.mounted) return;

                      // 다이얼로그 닫기
                      Navigator.of(dialogContext).pop();

                      if (!dialogContext.mounted) return;

                      // 홈의 탭을 채팅 목록으로 전환
                      widget.onNavigateToChat?.call();

                      // 채팅방으로 이동
                      Navigator.of(dialogContext).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ChatRoomPage(chatRoom: chatRoom),
                        ),
                      );
                    }
                  } catch (e) {
                    logDebug('Chat room navigation failed (${e.runtimeType})');
                    if (mounted && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                    }
                  }
                } else {
                  Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81C784),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                '채팅방 이동하기',
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

  Future<void> _refreshPostAndChatInfo(String? chatRoomId) async {
    Map<String, dynamic>? postDetail;
    Map<String, dynamic>? chatDetail;

    try {
      if (_userPostId != null) {
        final postResponse = await PostApi.getPost(_userPostId!);
        if (postResponse['success'] == true) {
          postDetail = _unwrapApiData(postResponse['data']);
        }
      }

      if (chatRoomId != null && chatRoomId.isNotEmpty) {
        final chatResponse = await ChatApi.getChatRoomInfo(chatRoomId);
        if (chatResponse['success'] == true) {
          chatDetail = _unwrapApiData(chatResponse['data']);
        }
      }
    } catch (e) {
      logDebug('Joint-order group refresh failed (${e.runtimeType})');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _latestPostDetail = postDetail;
      _latestChatRoomDetail = chatDetail;
    });
  }

  Widget? _buildUpdatedGroupSummaryCard() {
    final post = _latestPostDetail;
    final chat = _latestChatRoomDetail;
    if (post == null && chat == null) {
      return null;
    }

    final deliveryDetail = _coerceMap(
      post?['deliveryDetail'] ?? post?['delivery_detail'],
    );
    final currentPeople = _readInt(post, [
      'currentParticipants',
      'current_participants',
    ]);
    final maxPeople = _readInt(post, ['maxParticipants', 'max_participants']);
    final deliveryFee = _readInt(deliveryDetail, [
      'deliveryFee',
      'delivery_fee',
    ]);
    final targetAmount = _readInt(deliveryDetail, [
      'targetAmount',
      'target_amount',
    ]);
    final minOrderAmount = _readInt(deliveryDetail, [
      'minOrderAmount',
      'min_order_amount',
    ]);
    final chatCurrent = _readInt(chat, [
      'currentPeople',
      'memberCount',
      'current_participants',
    ]);
    final chatMax = _readInt(chat, [
      'maxPeople',
      'maxParticipants',
      'max_participants',
    ]);
    final meetingTime = _formatMeetingTimeString(
      post?['meetingTime'] ?? post?['deadline'],
    );

    final rows = <Widget>[];

    if (currentPeople != null && maxPeople != null) {
      rows.add(_buildInfoRow('모집 인원', '$currentPeople/$maxPeople명'));
    }
    if (chatCurrent != null && chatMax != null) {
      rows.add(_buildInfoRow('채팅방 인원', '$chatCurrent/$chatMax명'));
    }
    if (deliveryFee != null) {
      rows.add(_buildInfoRow('총 배달비', _formatCurrencyValue(deliveryFee)));
    }
    if (targetAmount != null) {
      rows.add(_buildInfoRow('목표 금액', _formatCurrencyValue(targetAmount)));
    }
    if (minOrderAmount != null) {
      rows.add(_buildInfoRow('최소 주문 금액', _formatCurrencyValue(minOrderAmount)));
    }
    if (meetingTime != null) {
      rows.add(_buildInfoRow('만남 시간', meetingTime));
    }

    if (rows.isEmpty) {
      return null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '업데이트된 대표 게시글 정보',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _unwrapApiData(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final nested = raw['data'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      return raw;
    }
    return null;
  }

  Map<String, dynamic>? _coerceMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  int? _readInt(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      if (source.containsKey(key)) {
        final parsed = _tryParseInt(source[key]);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String _formatCurrencyValue(int amount) {
    final number = amount.toString();
    final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formatted = number.replaceAllMapped(regex, (match) => ',');
    return '$formatted원';
  }

  String? _formatMeetingTimeString(dynamic raw) {
    DateTime? dateTime;
    if (raw is String && raw.isNotEmpty) {
      dateTime = DateTime.tryParse(raw);
    } else if (raw is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is DateTime) {
      dateTime = raw;
    }

    if (dateTime == null) {
      return null;
    }

    final amPm = dateTime.hour < 12 ? '오전' : '오후';
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute;
    final minuteLabel = minute == 0
        ? ''
        : ' ${minute.toString().padLeft(2, '0')}분';
    return '${dateTime.month}/${dateTime.day} $amPm $hour시$minuteLabel';
  }

  /// 매칭 실패 다이얼로그
  void _showMatchFailedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/Failed attempt.json',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              repeat: false,
            ),
            const SizedBox(height: 5),
            const Text(
              '매칭 실패!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              message,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // 그림자 제거
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF81C784)),
            )
          : _isMatching
          ? _buildWaitingScreen()
          : _matchablePosts.isEmpty
          ? _buildInitialScreen()
          : _buildMatchablePostsList(),
    );
  }

  /// 초기 화면 (매칭 시작 전)
  Widget _buildInitialScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/Search.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 30),
          const Text(
            '모집 인원이 \n 부족하신가요?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            '같은 음식점 · 배달 장소의 다른 게시글과 \n함께 주문해보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startMatching,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF81C784),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '합동 주문 매칭 시작',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 매칭 가능한 게시글 목록
  Widget _buildMatchablePostsList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '매칭된 밥동무 ${_matchablePosts.length}명',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '음식점/장소만 같다면 배달비는 다를 수 있어요.',
                style: TextStyle(fontSize: 14, color: Colors.redAccent),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _matchablePosts.length,
            itemBuilder: (context, index) {
              return _buildPostCard(_matchablePosts[index]);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasPendingRequest ? null : _sendJointOrderRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasPendingRequest
                      ? Colors.grey
                      : const Color(0xFF81C784),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _hasPendingRequest
                      ? '요청 진행 중'
                      : '요청하기 (${_matchablePosts.where((p) => p.isSelected).length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 게시글 카드
  Widget _buildPostCard(MatchablePost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: post.isSelected ? const Color(0xFF81C784) : Colors.grey[300]!,
          width: post.isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              post.isSelected = !post.isSelected;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF81C784),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              post.storeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${post.deliveryPlace} 출구 앞에서 만나요',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${post.currentPeople}/${post.maxPeople}명',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(post.deadline),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: post.isSelected,
                  onChanged: (value) {
                    setState(() {
                      post.isSelected = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF81C784),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 수락 대기 화면
  Widget _buildWaitingScreen() {
    final remainingTime = Duration(seconds: _remainingSeconds);
    final minutes = remainingTime.inMinutes;
    final seconds = remainingTime.inSeconds % 60;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80), // 상단 여백
                Lottie.asset(
                  'assets/Time Hourglass.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 5),
                const Text(
                  '수락 기다리는 중',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF81C784),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '상대방이 요청을 확인하고 있어요.\n잠시만 기다려 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 25),
                // 수락 인원 수 표시
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81C784).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF81C784).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '수락 인원: $_acceptedCount / $_totalTargetCount',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF81C784),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // 남은 시간 표시
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: minutes < 1
                        ? Colors.red.withValues(alpha: 0.1)
                        : const Color(0xFF81C784).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: minutes < 1
                          ? Colors.red.withValues(alpha: 0.3)
                          : const Color(0xFF81C784).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '남은 시간: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: minutes < 1 ? Colors.red : const Color(0xFF81C784),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: TextButton(
            onPressed: () {
              _statusCheckTimer?.cancel();
              setState(() {
                _isMatching = false;
                _hasPendingRequest = false; // 중복 요청 방지 상태 해제
                _matchablePosts.clear();
              });
            },
            child: const Text(
              '요청 취소',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String day;
    if (dDay == today) {
      day = '오늘';
    } else if (dDay == today.add(const Duration(days: 1))) {
      day = '내일';
    } else {
      day = '${dateTime.month}/${dateTime.day}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute;

    String amPm = hour < 12 ? '오전' : '오후';
    int halfH = hour % 12;
    if (halfH == 0) halfH = 12;

    String time = minute == 0 ? '$halfH시' : '$halfH시 $minute분';

    return '$day $amPm $time 마감';
  }
}
