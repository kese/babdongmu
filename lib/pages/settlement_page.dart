import 'package:flutter/material.dart';
import 'package:delivery/utils/logging.dart';
import '../models/shared_cart_data.dart';
import '../models/settlement_request.dart';
import '../services/api.dart';

/// 정산하기 페이지
class SettlementPage extends StatefulWidget {
  final String roomId;
  final String cartId;
  final String currentUserId;
  final List<CartMenuItem> myItems;
  final int deliveryFeePerPerson;
  final int totalAmount;
  final String hostNickname;
  final bool isHost; // 방장 여부

  const SettlementPage({
    super.key,
    required this.roomId,
    required this.cartId,
    required this.currentUserId,
    required this.myItems,
    required this.deliveryFeePerPerson,
    required this.totalAmount,
    required this.hostNickname,
    required this.isHost,
  });

  @override
  State<SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends State<SettlementPage> {
  bool _isProcessing = false;
  int _userPoints = 0;
  bool _isRequestLoading = false;
  List<SettlementRequest> _requests = const [];
  SettlementRequest? _myPendingRequest;
  SettlementRequest? _myLatestRequest;
  final Set<String> _processingRequestIds = <String>{};

  String get _receiverName {
    final trimmed = widget.hostNickname.trim();
    if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
      return trimmed;
    }
    return '방장';
  }

  @override
  void initState() {
    super.initState();
    _loadUserPoints();
    _loadSettlementRequests();
  }

  // 사용자 포인트 불러오기
  Future<void> _loadUserPoints() async {
    try {
      final result = await UserApi.getUserPoints();
      if (result['success'] == true && mounted) {
        setState(() {
          _userPoints = result['data']['points'] ?? 0;
        });
      }
    } catch (e) {
      logDebug('Point lookup failed (${e.runtimeType})');
    }
  }

  Future<void> _loadSettlementRequests() async {
    setState(() => _isRequestLoading = true);

    try {
      final result = await SharedCartApi.getSettlementRequests(
        roomId: widget.roomId,
        cartId: widget.cartId,
      );

      if (result['success'] == true && mounted) {
        final parsed = _parseRequestsFromResponse(result['data']);
        parsed.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        final myRequests =
            parsed
                .where((request) => request.requesterId == widget.currentUserId)
                .toList()
              ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        SettlementRequest? pending;
        for (final request in myRequests) {
          if (request.isPending) {
            pending = request;
            break;
          }
        }

        final latest = myRequests.isNotEmpty ? myRequests.first : null;

        setState(() {
          _requests = parsed;
          _myPendingRequest = pending;
          _myLatestRequest = latest;
        });
      } else if (result['success'] != true) {
        final message = result['message'];
        if (message is String && message.isNotEmpty) {
          logDebug('Settlement request list lookup failed');
        }
      }
    } catch (e) {
      logDebug('Settlement request list lookup failed (${e.runtimeType})');
    } finally {
      if (mounted) {
        setState(() => _isRequestLoading = false);
      }
    }
  }

  List<SettlementRequest> _parseRequestsFromResponse(dynamic data) {
    if (data == null) {
      return const [];
    }

    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) => SettlementRequest.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: true);
    }

    if (data is Map) {
      final map = data.map((key, value) => MapEntry(key.toString(), value));
      const candidates = [
        'requests',
        'data',
        'items',
        'list',
        'content',
        'results',
      ];

      for (final key in candidates) {
        if (!map.containsKey(key)) {
          continue;
        }
        final parsed = _parseRequestsFromResponse(map[key]);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }

      if (_looksLikeRequestMap(map)) {
        return [SettlementRequest.fromJson(map)];
      }
    }

    return const [];
  }

  bool _looksLikeRequestMap(Map<String, dynamic> data) {
    return data.containsKey('requestId') || data.containsKey('request_id');
  }

  bool _isProcessingRequest(String requestId) {
    return _processingRequestIds.contains(requestId);
  }

  void _setProcessingRequest(String requestId, bool processing) {
    if (processing) {
      _processingRequestIds.add(requestId);
    } else {
      _processingRequestIds.remove(requestId);
    }
  }

  Future<void> _approveRequest(SettlementRequest request) async {
    if (_isProcessingRequest(request.requestId)) {
      return;
    }

    setState(() => _setProcessingRequest(request.requestId, true));

    try {
      final response = await SharedCartApi.approveSettlementRequest(
        roomId: widget.roomId,
        requestId: request.requestId,
      );

      if (!mounted) {
        return;
      }

      if (response['success'] == true) {
        final displayName = request.requesterNickname.isNotEmpty
            ? request.requesterNickname
            : '참여자';


        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$displayName님의 요청을 승인했습니다.')));
        }
        await _loadSettlementRequests();

        // 채팅방 페이지에 실시간 업데이트 신호 전송
        if (mounted) {
          Navigator.pop(context, {'settlementUpdated': true});
        }
      } else {
        final message = response['message'] ?? '요청 승인에 실패했습니다.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('요청 승인 중 오류가 발생했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _setProcessingRequest(request.requestId, false));
      } else {
        _setProcessingRequest(request.requestId, false);
      }
    }
  }

  Future<void> _rejectRequest(
    SettlementRequest request, {
    bool isSelfCancel = false,
    String? memo,
  }) async {
    if (_isProcessingRequest(request.requestId)) {
      return;
    }

    setState(() => _setProcessingRequest(request.requestId, true));

    try {
      final response = await SharedCartApi.rejectSettlementRequest(
        roomId: widget.roomId,
        requestId: request.requestId,
        decisionMemo: memo,
      );

      if (!mounted) {
        return;
      }

      if (response['success'] == true) {
        final message = isSelfCancel ? '결제 요청을 취소했습니다.' : '요청을 거절했습니다.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        await _loadSettlementRequests();

        // 채팅방 페이지에 실시간 업데이트 신호 전송
        if (mounted) {
          Navigator.pop(context, {'settlementUpdated': true});
        }
      } else {
        final message = response['message'] ?? '요청 처리에 실패했습니다.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('요청 처리 중 오류가 발생했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _setProcessingRequest(request.requestId, false));
      } else {
        _setProcessingRequest(request.requestId, false);
      }
    }
  }

  Future<void> _cancelMyRequest(SettlementRequest request) async {
    await _rejectRequest(request, isSelfCancel: true, memo: '사용자 취소');
  }

  Widget? _buildParticipantRequestSection() {
    if (widget.isHost) {
      return null;
    }

    final request = _myPendingRequest ?? _myLatestRequest;
    if (request == null) {
      return null;
    }

    final status = request.status.toUpperCase();
    late Color backgroundColor;
    late Color borderColor;
    late Color textColor;
    late IconData icon;
    late String title;
    late String message;
    final List<Widget> actions = [];

    switch (status) {
      case 'PENDING':
        backgroundColor = const Color(0xFFE3F2FD);
        borderColor = const Color(0xFF90CAF9);
        textColor = const Color(0xFF1565C0);
        icon = Icons.hourglass_top;
        title = '결제 승인 대기 중';
        message = '방장이 승인하면 ${_formatNumber(request.amount)}원이 차감됩니다.';
        final isProcessing = _isProcessingRequest(request.requestId);
        actions.add(
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isProcessing ? null : () => _cancelMyRequest(request),
              child: isProcessing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('요청 취소'),
            ),
          ),
        );
        break;
      case 'APPROVED':
        backgroundColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFFA5D6A7);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.check_circle;
        title = '승인 완료';
        message = '$_receiverName님이 결제 요청을 승인했습니다.';
        break;
      case 'REJECTED':
      default:
        backgroundColor = const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFFE0B2);
        textColor = const Color(0xFFEF6C00);
        icon = Icons.info_outline;
        title = '결제 요청이 거절되었습니다';
        message = '사유를 확인한 뒤 다시 요청해 주세요.';
        if (request.decisionMemo != null && request.decisionMemo!.isNotEmpty) {
          message += '\n사유: ${request.decisionMemo}';
        }
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontSize: 13, color: textColor)),
          const SizedBox(height: 8),
          Text(
            '요청 금액: ${_formatNumber(request.amount)}원',
            style: TextStyle(fontSize: 13, color: textColor),
          ),
          if (request.deliveryFeeShare != null)
            Text(
              '배달비 몫: ${_formatNumber(request.deliveryFeeShare!)}원',
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          Text(
            '요청 시간: ${_formatRequestTimestamp(request.requestedAt)}',
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8)),
          ),
          if (status == 'APPROVED' && request.processedAt != null)
            Text(
              '처리 시간: ${_formatRequestTimestamp(request.processedAt!)}',
              style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8)),
            ),
          if (actions.isNotEmpty) ...[const SizedBox(height: 12), ...actions],
        ],
      ),
    );
  }

  Widget _buildHostRequestSection() {
    final sorted = List<SettlementRequest>.from(_requests)
      ..sort((a, b) {
        if (a.isPending && !b.isPending) return -1;
        if (!a.isPending && b.isPending) return 1;
        return b.requestedAt.compareTo(a.requestedAt);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '결제 요청 관리',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_isRequestLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (sorted.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '도착한 결제 요청이 없습니다.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          )
        else
          Column(
            children: sorted
                .map((request) => _buildHostRequestCard(request))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildHostRequestCard(SettlementRequest request) {
    final isPending = request.isPending;
    final isProcessing = _isProcessingRequest(request.requestId);
    final displayName = request.requesterNickname.isNotEmpty
        ? request.requesterNickname
        : '참여자';
    final status = request.status.toUpperCase();

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'APPROVED':
        statusColor = const Color(0xFF2E7D32);
        statusLabel = '승인됨';
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFEF6C00);
        statusLabel = '거절됨';
        break;
      default:
        statusColor = const Color(0xFF1565C0);
        statusLabel = '대기 중';
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '요청 금액: ${_formatNumber(request.amount)}원',
            style: const TextStyle(fontSize: 13),
          ),
          if (request.deliveryFeeShare != null)
            Text(
              '배달비 몫: ${_formatNumber(request.deliveryFeeShare!)}원',
              style: const TextStyle(fontSize: 13),
            ),
          Text(
            '요청 시간: ${_formatRequestTimestamp(request.requestedAt)}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (request.memo != null && request.memo!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '요청 메모: ${request.memo}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
          if (request.decisionMemo != null &&
              request.decisionMemo!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '결정 메모: ${request.decisionMemo}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
          if (request.processedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '처리 시간: ${_formatRequestTimestamp(request.processedAt!)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _approveRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81C784),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('승인'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _rejectRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF6C00),
                      side: const BorderSide(color: Color(0xFFEF6C00)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('거절'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatRequestTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  // 포인트 결제 처리
  Future<void> _processPayment() async {
    if (_myPendingRequest != null && _myPendingRequest!.isPending) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 승인 대기 중인 결제 요청이 있습니다.')));
      return;
    }

    if (_userPoints < widget.totalAmount) {
      _showInsufficientPointsDialog();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final response = await SharedCartApi.createSettlementRequest(
        roomId: widget.roomId,
        cartId: widget.cartId,
        amount: widget.totalAmount,
        deliveryFeeShare: widget.deliveryFeePerPerson > 0
            ? widget.deliveryFeePerPerson
            : null,
        memo: '앱에서 자동 생성된 결제 요청',
      );

      if (!mounted) return;

      if (response['success'] == true) {
        SettlementRequest? createdRequest;
        final data = response['data'];
        if (data is Map) {
          final map = data.map((key, value) => MapEntry(key.toString(), value));
          createdRequest = SettlementRequest.fromJson(map);
        }

        setState(() {
          if (createdRequest != null) {
            _myPendingRequest = createdRequest.isPending
                ? createdRequest
                : null;
            _myLatestRequest = createdRequest;
          }
        });

        bool autoApproved = false;
        String? autoApproveError;

        if (widget.isHost && createdRequest != null) {
          final approveResponse = await SharedCartApi.approveSettlementRequest(
            roomId: widget.roomId,
            requestId: createdRequest.requestId,
            decisionMemo: '방장 자가 결제 자동 승인',
          );

          if (!mounted) {
            return;
          }

          if (approveResponse['success'] == true) {
            autoApproved = true;
            final approvedData = approveResponse['data'];
            if (approvedData is Map) {
              final normalized = approvedData.map(
                (key, value) => MapEntry(key.toString(), value),
              );
              final parsed = SettlementRequest.fromJson(normalized);
              setState(() {
                _myPendingRequest = parsed.isPending ? parsed : null;
                _myLatestRequest = parsed;
              });
            }
          } else {
            autoApproveError =
                approveResponse['message']?.toString() ?? '결제 승인 처리에 실패했습니다.';
          }
        }

        await _loadSettlementRequests();

        if (!mounted) {
          return;
        }

        final formattedAmount = _formatNumber(widget.totalAmount);
        String dialogTitle;
        final buffer = StringBuffer();

        if (autoApproved) {
          dialogTitle = '결제 완료';
          buffer
            ..write('$formattedAmount원 결제를 완료했습니다.')
            ..write('\n\n승인 내역이 최신 상태로 반영되었습니다.');
        } else {
          dialogTitle = '결제 요청 완료';
          if (widget.isHost) {
            buffer
              ..write('$formattedAmount원 결제 요청을 생성했습니다.')
              ..write('\n\n요청 목록에서 승인해 주세요.');
            if (autoApproveError != null && autoApproveError.isNotEmpty) {
              buffer
                ..write('\n\n자동 승인에 실패했습니다: ')
                ..write(autoApproveError);
            }
          } else {
            buffer
              ..write('$_receiverName님에게 $formattedAmount원 결제를 요청했습니다.')
              ..write('\n\n방장이 승인을 완료하면 포인트가 자동으로 차감됩니다.');
          }
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  autoApproved ? Icons.verified : Icons.check_circle,
                  color: const Color(0xFF81C784),
                ),
                const SizedBox(width: 8),
                Text(dialogTitle),
              ],
            ),
            content: Text(buffer.toString()),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text(
                  '확인',
                  style: TextStyle(color: Color(0xFF81C784)),
                ),
              ),
            ],
          ),
        );
      } else {
        final errorMessage = response['message'] ?? '결제에 실패했습니다';
        if (errorMessage.contains('방장만')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('정산은 방장만 처리할 수 있습니다. 방장에게 요청해 주세요.')),
          );
        } else if (errorMessage.contains('중복') ||
            errorMessage.contains('대기 중')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 처리 대기 중인 결제 요청이 있습니다.')),
          );
        } else if (errorMessage.contains('포인트') ||
            errorMessage.contains('부족')) {
          _showInsufficientPointsDialog();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // 포인트 부족 다이얼로그
  void _showInsufficientPointsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('포인트 부족'),
          ],
        ),
        content: Text(
          '보유 포인트가 부족합니다.\n\n'
          '필요 금액: ${_formatNumber(widget.totalAmount)} P\n'
          '보유 포인트: ${_formatNumber(_userPoints)} P\n\n'
          '포인트를 충전해 주세요.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final myItemsTotal = widget.myItems.fold(
      0,
      (sum, item) => sum + item.price,
    );
    final isHostView = widget.isHost;
    final participantRequestSection = !isHostView
        ? _buildParticipantRequestSection()
        : null;
    final hostRequestSection = isHostView ? _buildHostRequestSection() : null;
    final latestRequestStatus = _myLatestRequest?.status.toUpperCase();
    final hasPendingRequest = _myPendingRequest?.isPending ?? false;
    final isApprovedRequest = latestRequestStatus == 'APPROVED';
    final isButtonDisabled =
        _isProcessing || hasPendingRequest || isApprovedRequest;
    final formattedTotalAmount = _formatNumber(widget.totalAmount);

    String buttonLabel;
    if (hasPendingRequest) {
      buttonLabel = '승인 대기 중';
    } else if (latestRequestStatus == 'APPROVED') {
      buttonLabel = '승인 완료';
    } else if (latestRequestStatus == 'REJECTED') {
      buttonLabel = '$formattedTotalAmount원 다시 결제하기';
    } else {
      buttonLabel = '$formattedTotalAmount원 결제하기';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF81C784),
        title: const Text(
          '정산하기',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isHostView)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _isRequestLoading
                  ? null
                  : () => _loadSettlementRequests(),
            ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 방장 정보
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_circle,
                            color: Color(0xFF81C784),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '결제 승인 담당자',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _receiverName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (participantRequestSection != null) ...[
                    participantRequestSection,
                    const SizedBox(height: 24),
                  ],

                  if (hostRequestSection != null) ...[
                    hostRequestSection,
                    const SizedBox(height: 24),
                  ],

                  // 내 주문 내역
                  const Text(
                    '내 주문 내역',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ...widget.myItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  '${item.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.myItems.isNotEmpty) const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '메뉴 합계',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${myItemsTotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF81C784),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 배달비
                  const Text(
                    '배달비',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('인당 배달비', style: TextStyle(fontSize: 14)),
                        Text(
                          '${widget.deliveryFeePerPerson.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isHostView)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBDEFB)),
                        ),
                        child: const Text(
                          '방장도 결제 대상입니다. 결제를 완료하면 정산 현황이 즉시 업데이트됩니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ),

                  // 총 결제 금액
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '총 결제 금액',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF81C784),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 결제 버튼
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isButtonDisabled ? null : () => _processPayment(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C784),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          buttonLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
