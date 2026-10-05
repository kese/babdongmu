import 'dart:async';
import 'dart:convert';
import '../models/notification_data.dart';
import 'api.dart';
import '../utils/logging.dart';
import '../dummy_data/dummy_notification_data.dart';

/// 앱 내 알림 API 서비스
class AppNotificationApi {
  AppNotificationApi._();

  static final StreamController<List<NotificationData>>
  _notificationsController =
      StreamController<List<NotificationData>>.broadcast();

  static final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  static List<NotificationData> _notifications = [];
  static bool _initialized = false;

  /// 알림 목록 스트림
  static Stream<List<NotificationData>> get notificationsStream =>
      _notificationsController.stream;

  /// 읽지 않은 알림 개수 스트림
  static Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// 현재 알림 목록 (최신순)
  static List<NotificationData> get notifications =>
      List.unmodifiable(_notifications);

  /// 읽지 않은 알림 개수
  static int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// 초기화 및 서버에서 알림 로드
  static Future<void> initialize() async {
    if (_initialized) return;

    await fetchNotifications();
    _initialized = true;
  }

  /// 서버에서 알림 목록 조회
  static Future<void> fetchNotifications() async {
    if (ApiService.isDevelopment) {
      // 개발 모드: 더미 데이터 사용
      await Future.delayed(const Duration(milliseconds: 300));
      _notifications = List.from(DummyNotificationData.sampleNotifications);
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _notifyListeners();
      logDebug(
        '[AppNotificationApi] (Dev) 알림 조회 완료: ${_notifications.length}개',
      );
      return;
    }

    try {
      final result = await ApiService.get(
        'api/v1/notifications',
        requiresAuth: true,
      );

      // 403 Forbidden 에러 처리 (서버 권한 설정 문제)
      if (result['statusCode'] == 403) {
        logDebug(
          '🚨 [AppNotificationApi] 권한 부족 (403): 서버 Security 설정을 확인해주세요.',
        );
        // FCM 알림은 보존
        _notifications = _notifications
            .where((n) => n.id.startsWith('fcm_'))
            .toList();
        _notifyListeners();
        return;
      }

      // 401 Unauthorized 에러 처리 (토큰 만료/인증 실패)
      if (result['statusCode'] == 401) {
        logDebug('🚨 [AppNotificationApi] 인증 실패 (401): 토큰이 만료되었거나 유효하지 않습니다.');
        // FCM 알림은 보존
        _notifications = _notifications
            .where((n) => n.id.startsWith('fcm_'))
            .toList();
        _notifyListeners();
        return;
      }

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];

        final List<NotificationData> serverNotifications = [];
        for (final json in data) {
          try {
            serverNotifications.add(
              NotificationData.fromJson(json as Map<String, dynamic>),
            );
          } catch (e) {
            logDebug('Notification item parsing failed (${e.runtimeType})');
          }
        }

        // FCM으로 추가된 알림 (id가 'fcm_'으로 시작) 보존
        final fcmNotifications = _notifications
            .where((n) => n.id.startsWith('fcm_'))
            .toList();

        // 서버 알림과 FCM 알림 병합 (중복 제거)
        final Set<String> serverIds = serverNotifications
            .map((n) => n.id)
            .toSet();
        final uniqueFcmNotifications = fcmNotifications
            .where((n) => !serverIds.contains(n.id))
            .toList();

        _notifications = [...uniqueFcmNotifications, ...serverNotifications];

        // 최신순 정렬
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        _notifyListeners();
        logDebug(
          '[AppNotificationApi] 알림 조회 성공: 서버=${serverNotifications.length}개, FCM=${uniqueFcmNotifications.length}개, 총=${_notifications.length}개',
        );
      } else {
        logDebug('[AppNotificationApi] Notification fetch failed');
        // 실패 시에도 빈 리스트로 처리하여 앱 안정성 유지
        if (_notifications.isEmpty) {
          _notifyListeners();
        }
      }
    } catch (e) {
      logDebug('Notification fetch failed (${e.runtimeType})');
      // 예외 발생 시에도 FCM 알림은 보존
      final fcmNotifications = _notifications
          .where((n) => n.id.startsWith('fcm_'))
          .toList();
      if (fcmNotifications.isNotEmpty) {
        _notifications = fcmNotifications;
        _notifyListeners();
        logDebug('[AppNotificationApi] FCM 알림 ${fcmNotifications.length}개 보존');
      } else if (_notifications.isEmpty) {
        _notifyListeners();
      }
    }
  }

  /// 새 알림 추가 (로컬 UI 업데이트용, 서버에는 이미 존재한다고 가정하거나 별도 푸시로 수신됨)
  /// 만약 클라이언트 생성 알림을 서버에 저장해야 한다면 POST 요청 필요
  static Future<void> addNotification(NotificationData notification) async {
    // 로컬 리스트에 우선 추가하여 UI 즉시 반영
    _notifications.insert(0, notification);
    _notifyListeners();

    // 필요시 서버 목록 다시 조회
    // await fetchNotifications();
  }

  /// 알림 읽음 처리
  static Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      // UI 업데이트
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notifyListeners();

      if (ApiService.isDevelopment) {
        // 개발 모드: 로컬 상태만 변경
        logDebug('[AppNotificationApi] Mock notification marked read');
        return;
      }

      try {
        // API 호출
        await ApiService.put(
          'api/v1/notifications/$notificationId/read',
          {},
          requiresAuth: true,
        );
      } catch (e) {
        logDebug('Notification read update failed (${e.runtimeType})');
        // 실패 시 롤백 로직이 필요할 수 있음
      }
    }
  }

  /// 모든 알림 읽음 처리
  static Future<void> markAllAsRead() async {
    bool hasUnread = _notifications.any((n) => !n.isRead);

    if (hasUnread) {
      // 낙관적 UI 업데이트
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      _notifyListeners();

      if (ApiService.isDevelopment) {
        // 개발 모드: 로컬 상태만 변경
        logDebug('[AppNotificationApi] (Dev) 전체 읽음 처리');
        return;
      }

      try {
        await ApiService.put(
          'api/v1/notifications/read-all',
          {},
          requiresAuth: true,
        );
      } catch (e) {
        logDebug('Mark all notifications read failed (${e.runtimeType})');
      }
    }
  }

  /// 알림 삭제
  static Future<void> deleteNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      // 낙관적 UI 업데이트
      final removed = _notifications.removeAt(index);
      _notifyListeners();

      if (ApiService.isDevelopment) {
        // 개발 모드: 로컬 리스트에서만 삭제
        logDebug('[AppNotificationApi] Mock notification deleted');
        return;
      }

      try {
        await ApiService.delete(
          'api/v1/notifications/$notificationId',
          requiresAuth: true,
        );
      } catch (e) {
        logDebug('Notification deletion failed (${e.runtimeType})');
        // 실패 시 복구
        _notifications.insert(index, removed);
        _notifyListeners();
      }
    }
  }

  /// 모든 알림 삭제
  static Future<void> clearAll() async {
    if (_notifications.isNotEmpty) {
      final backup = List<NotificationData>.from(_notifications);
      _notifications.clear();
      _notifyListeners();

      if (ApiService.isDevelopment) {
        // 개발 모드: 로컬 리스트만 초기화
        logDebug('[AppNotificationApi] (Dev) 전체 삭제');
        return;
      }

      try {
        await ApiService.delete('api/v1/notifications', requiresAuth: true);
      } catch (e) {
        logDebug('Clear notifications failed (${e.runtimeType})');
        _notifications = backup;
        _notifyListeners();
      }
    }
  }

  /// 리스너들에게 변경 알림
  static void _notifyListeners() {
    _notificationsController.add(List.unmodifiable(_notifications));
    _unreadCountController.add(unreadCount);
  }

  /// 리소스 정리
  static void dispose() {
    _notificationsController.close();
    _unreadCountController.close();
  }
}
