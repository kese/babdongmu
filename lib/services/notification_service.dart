import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logging.dart';
import '../models/notification_data.dart';
import 'api.dart';
import 'app_notification_api.dart';

/// Firebase Cloud Messaging 백그라운드 핸들러.
/// 앱이 완전히 종료된 상태에서도 호출될 수 있으므로, 엔트리 포인트로 지정한다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.ensureFirebaseInitialized();
  NotificationService.handleBackgroundMessage(message);
}

/// 앱 내 FCM 초기화 및 공통 처리 유틸리티.
class NotificationService {
  NotificationService._();

  static const _firebaseEnabled = bool.fromEnvironment(
    'APP_ENABLE_FIREBASE',
    defaultValue: false,
  );
  static const _deviceIdKey = 'notification_device_id';
  static const _jointOrderChannelId = 'joint_order_channel';
  static const _jointOrderChannelName = 'Joint Order Notifications';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final StreamController<JointOrderRequestPayload>
  _jointOrderRequestController =
      StreamController<JointOrderRequestPayload>.broadcast();
  static final StreamController<JointOrderStatusPayload>
  _jointOrderStatusController =
      StreamController<JointOrderStatusPayload>.broadcast();
  static final StreamController<String> _postUpdateController =
      StreamController<String>.broadcast();
  static final StreamController<SharedCartStatusPayload>
  _sharedCartStatusController =
      StreamController<SharedCartStatusPayload>.broadcast();

  static bool _firebaseReady = false;
  static bool _initialized = false;
  static bool _fcmEnabled = false;
  static String? _lastSyncedToken;

  static Stream<JointOrderRequestPayload> get jointOrderRequests =>
      _jointOrderRequestController.stream;
  static Stream<JointOrderStatusPayload> get jointOrderStatusUpdates =>
      _jointOrderStatusController.stream;
  static Stream<String> get postUpdates => _postUpdateController.stream;
  static Stream<SharedCartStatusPayload> get sharedCartStatusUpdates =>
      _sharedCartStatusController.stream;

  static bool get isFcmEnabled => _fcmEnabled;

  /// Firebase 인스턴스 초기화 보장.
  static Future<void> ensureFirebaseInitialized() async {
    if (!_firebaseEnabled) {
      return;
    }
    if (_firebaseReady) {
      return;
    }
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      logDebug('Firebase initialization failed (${e.runtimeType})');
    }
  }

  /// FCM 초기화 및 스트림 리스너 구성.
  static Future<void> initialize() async {
    if (_initialized || !_firebaseEnabled) {
      return;
    }

    await ensureFirebaseInitialized();
    if (!_firebaseReady) {
      return;
    }

    try {
      await _setupLocalNotifications();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      _fcmEnabled =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((message) {
        _handleMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleMessage(message, fromNotificationTap: true);
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage, fromNotificationTap: true);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _sendTokenToServer(token, force: true);
      });

      _initialized = true;
    } catch (e) {
      _fcmEnabled = false;
      logDebug('Notification initialization failed (${e.runtimeType})');
    }
  }

  /// 로컬 알림 플러그인 초기화.
  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);
  }

  /// 포그라운드/백그라운드 공용 메시지 처리.
  static void _handleMessage(
    RemoteMessage message, {
    bool fromNotificationTap = false,
  }) {
    final payloadMap = _extractPayload(message);
    if (payloadMap == null) {
      logDebug('[NotificationService] ⚠️ 빈 payload 메시지 수신');
      return;
    }

    // 포그라운드 메시지 수신 로그
    logDebug('FCM foreground message received');
    logDebug('🔥 [FCM] fromNotificationTap: $fromNotificationTap');

    final type = payloadMap['type']?.toString() ?? '';
    final normalizedType = type.toLowerCase();

    // type이 없는 경우에도 알림 처리
    if (type.isEmpty) {
      logDebug('[NotificationService] type이 없는 메시지 수신 - 일반 알림으로 처리');

      final title = payloadMap['title']?.toString() ?? '새 알림';
      final body =
          payloadMap['body']?.toString() ??
          payloadMap['message']?.toString() ??
          '';

      if (title.isNotEmpty || body.isNotEmpty) {
        _showLocalNotification(title: title, body: body);
        _addToAppNotifications(
          type: 'general',
          title: title,
          message: body.isNotEmpty ? body : '새로운 알림이 도착했습니다.',
          metadata: Map<String, dynamic>.from(payloadMap),
        );
      }
      return;
    }
    logDebug('[NotificationService] 메시지 타입: $type (정규화: $normalizedType)');

    if (normalizedType == 'joint_order_request') {
      final payload = JointOrderRequestPayload.fromMap(payloadMap);
      if (payload == null) {
        logDebug('[NotificationService] ⚠️ JointOrderRequestPayload 파싱 실패');
        return;
      }
      logDebug('[NotificationService] Joint-order request received');
      _jointOrderRequestController.add(payload);
      _showLocalNotification(
        title: '새 합동 주문 요청',
        body: _buildRequestBody(payload),
      );

      // 앱 내 알림 목록에 추가
      _addToAppNotifications(
        type: 'joint_order_request',
        title: '새 합동 주문 요청',
        message: _buildRequestBody(payload),
        metadata: {
          'requestId': payload.requestId,
          'requesterName': payload.requesterName,
        },
      );
    } else if (normalizedType == 'joint_order_update') {
      final payload = JointOrderStatusPayload.fromMap(payloadMap);
      if (payload == null) {
        return;
      }
      logDebug('[NotificationService] 🔔 합동 주문 상태 업데이트 스트림 전송');
      _jointOrderStatusController.add(payload);
      _showLocalNotification(
        title: '합동 주문 상태 변경',
        body: _buildStatusBody(payload),
      );

      // 앱 내 알림 목록에 추가
      _addToAppNotifications(
        type: 'joint_order_status',
        title: '합동 주문 상태 변경',
        message: _buildStatusBody(payload),
        metadata: {
          'requestId': payload.requestId,
          'status': payload.status,
          'chatRoomId': payload.chatRoomId,
        },
      );
    } else if (normalizedType == 'post_update' ||
        normalizedType == 'post_status_changed') {
      // 게시물 상태 변경 알림
      final postId =
          payloadMap['post_id']?.toString() ?? payloadMap['postId']?.toString();
      if (postId != null && postId.isNotEmpty) {
        _postUpdateController.add(postId);
        logDebug('[NotificationService] Post update notification received');

        // 앱 내 알림 목록에 추가
        _addToAppNotifications(
          type: 'post_update',
          title: '게시물 상태 변경',
          message: '게시물이 업데이트되었습니다.',
          metadata: {'postId': postId},
        );
      }
    } else if (normalizedType == 'shared_cart_status') {
      // 공동 장바구니 상태 변경 알림
      final payload = SharedCartStatusPayload.fromMap(payloadMap);
      if (payload == null) {
        logDebug('[NotificationService] ⚠️ SharedCartStatusPayload 파싱 실패');
        return;
      }

      logDebug(
        '[NotificationService] 🛒 공동 장바구니 상태 알림: eventType=${payload.eventType}, roomId=${payload.roomId}',
      );
      _sharedCartStatusController.add(payload);
      _showLocalNotification(
        title: payload.displayTitle,
        body: payload.displayMessage,
      );

      // 앱 내 알림 목록에 추가
      _addToAppNotifications(
        type: 'shared_cart_status',
        title: payload.displayTitle,
        message: payload.displayMessage,
        metadata: {'eventType': payload.eventType, 'roomId': payload.roomId},
      );
    } else {
      // 기타 모든 FCM 알림도 앱 내 알림에 추가
      logDebug('[NotificationService] 기타 알림 타입: $type');

      final title =
          payloadMap['title']?.toString() ??
          payloadMap['notification_title']?.toString() ??
          '새 알림';
      final body =
          payloadMap['body']?.toString() ??
          payloadMap['message']?.toString() ??
          payloadMap['notification_body']?.toString() ??
          '';

      _showLocalNotification(title: title, body: body);

      _addToAppNotifications(
        type: normalizedType,
        title: title,
        message: body.isNotEmpty ? body : '새로운 알림이 도착했습니다.',
        metadata: Map<String, dynamic>.from(payloadMap),
      );
    }

    // FCM 푸시 받을 때마다 서버 알림 목록도 새로고침 시도
    AppNotificationApi.fetchNotifications();
  }

  static Map<String, dynamic>? _extractPayload(RemoteMessage message) {
    final Map<String, dynamic> payload = {};

    // data 필드 추출
    if (message.data.isNotEmpty) {
      payload.addAll(message.data.map((key, value) => MapEntry(key, value)));
    }

    // notification 필드 추출 (data에 title/body가 없을 경우 사용)
    if (message.notification != null) {
      if (payload['title'] == null && message.notification!.title != null) {
        payload['title'] = message.notification!.title;
      }
      if (payload['body'] == null && message.notification!.body != null) {
        payload['body'] = message.notification!.body;
      }
    }

    if (payload.isEmpty) {
      return null;
    }

    return payload;
  }

  static String _buildRequestBody(JointOrderRequestPayload payload) {
    final requester = payload.requesterName ?? '익명';
    final store = payload.storeName ?? '주문 요청';
    final place = payload.deliveryPlace;
    if (place != null && place.isNotEmpty) {
      return '$requester님이 $store (${payload.deliveryPlace}) 합동 주문을 요청했습니다.';
    }
    return '$requester님이 $store 합동 주문을 요청했습니다.';
  }

  static String _buildStatusBody(JointOrderStatusPayload payload) {
    switch (payload.status.toLowerCase()) {
      case 'matched':
        return '모든 참여자가 수락해 새로운 채팅방이 개설되었습니다.';
      case 'accepted':
        return '요청이 수락되었습니다.';
      case 'rejected':
        return '요청이 거절되었습니다.';
      case 'timeout':
        return '응답 지연으로 요청이 만료되었습니다.';
      default:
        return '합동 주문 상태가 ${payload.status}로 변경되었습니다.';
    }
  }

  /// FCM 알림을 앱 내 알림 목록에 추가
  static void _addToAppNotifications({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    final notification = NotificationData(
      id: 'fcm_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
      metadata: metadata,
    );
    AppNotificationApi.addNotification(notification);
    logDebug('[NotificationService] In-app notification added');
  }

  /// 백그라운드 메시지용 처리 (로컬 노티만 표시).
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final payloadMap = _extractPayload(message);
    if (payloadMap == null) {
      return;
    }

    final type = payloadMap['type']?.toString();
    if (type == null) {
      return;
    }

    if (type == 'joint_order_request') {
      final payload = JointOrderRequestPayload.fromMap(payloadMap);
      if (payload != null) {
        await _showLocalNotification(
          title: '새 합동 주문 요청',
          body: _buildRequestBody(payload),
        );
      }
    } else if (type == 'joint_order_update') {
      final payload = JointOrderStatusPayload.fromMap(payloadMap);
      if (payload != null) {
        await _showLocalNotification(
          title: '합동 주문 상태 변경',
          body: _buildStatusBody(payload),
        );
      }
    }
  }

  /// 현재 로그인 사용자 기준 FCM 토큰을 서버와 동기화.
  static Future<void> syncFcmTokenWithServer({bool force = false}) async {
    if (!_fcmEnabled) {
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _sendTokenToServer(token, force: force);
  }

  /// 서버에서 토큰 등록 해제.
  static Future<void> unregisterToken() async {
    if (!_fcmEnabled) {
      return;
    }
    try {
      final authToken = await ApiService.getToken();
      if (authToken == null) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await ApiService.delete(
        'api/v1/notifications/tokens',
        requiresAuth: true,
        body: {'token': token},
      );
      _lastSyncedToken = null;
    } catch (e) {
      logDebug('[NotificationService] Token removal failed (${e.runtimeType})');
    }
  }

  static Future<void> _sendTokenToServer(
    String token, {
    bool force = false,
  }) async {
    try {
      final authToken = await ApiService.getToken();
      if (authToken == null) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!force && _lastSyncedToken == token) {
        return;
      }
      final deviceId = await _resolveDeviceId(prefs);
      final result = await ApiService.post('api/v1/notifications/tokens', {
        'token': token,
        'deviceId': deviceId,
      }, requiresAuth: true);
      if (result['success'] == true) {
        _lastSyncedToken = token;
      } else {
        logDebug('[NotificationService] Token sync failed');
      }
    } catch (e) {
      logDebug('[NotificationService] Token sync failed (${e.runtimeType})');
    }
  }

  static Future<String> _resolveDeviceId(SharedPreferences prefs) async {
    final cached = prefs.getString(_deviceIdKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final random = Random();
    final buffer = StringBuffer('flutter-device-');
    for (var i = 0; i < 16; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    final newId = buffer.toString();
    await prefs.setString(_deviceIdKey, newId);
    return newId;
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      return;
    }
    const androidDetails = AndroidNotificationDetails(
      _jointOrderChannelId,
      _jointOrderChannelName,
      channelDescription: '합동 주문/상태 알림 채널',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      1 << 31,
    );
    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
    );
  }
}

/// 합동 주문 요청 알림 페이로드.
class JointOrderRequestPayload {
  const JointOrderRequestPayload({
    required this.requestId,
    this.requesterId,
    this.requesterName,
    this.postId,
    this.storeName,
    this.deliveryPlace,
    this.orderTime,
    required this.raw,
  });

  final String requestId;
  final String? requesterId;
  final String? requesterName;
  final String? postId;
  final String? storeName;
  final String? deliveryPlace;
  final DateTime? orderTime;
  final Map<String, dynamic> raw;

  static JointOrderRequestPayload? fromMap(Map<String, dynamic> map) {
    final requestId = (map['requestId'] ?? map['request_id'] ?? map['id'])
        ?.toString();
    if (requestId == null || requestId.isEmpty) {
      return null;
    }
    final orderTimeRaw = map['orderTime'] ?? map['order_time'];
    DateTime? parsedOrderTime;
    if (orderTimeRaw is String && orderTimeRaw.isNotEmpty) {
      parsedOrderTime = DateTime.tryParse(orderTimeRaw);
    }
    return JointOrderRequestPayload(
      requestId: requestId,
      requesterId: (map['requesterId'] ?? map['requester_id'])?.toString(),
      requesterName: (map['requesterName'] ?? map['requester_name'])
          ?.toString(),
      postId: (map['postId'] ?? map['post_id'])?.toString(),
      storeName: (map['storeName'] ?? map['store_name'])?.toString(),
      deliveryPlace: (map['deliveryPlace'] ?? map['delivery_place'])
          ?.toString(),
      orderTime: parsedOrderTime,
      raw: map,
    );
  }
}

/// 합동 주문 상태 알림 페이로드.
class JointOrderStatusPayload {
  const JointOrderStatusPayload({
    required this.requestId,
    required this.status,
    this.chatRoomId,
    this.postId,
    required this.raw,
  });

  final String requestId;
  final String status;
  final String? chatRoomId;
  final String? postId;
  final Map<String, dynamic> raw;

  static JointOrderStatusPayload? fromMap(Map<String, dynamic> map) {
    final requestId = (map['requestId'] ?? map['request_id'] ?? map['id'])
        ?.toString();
    final status = (map['status'] ?? map['requestStatus'])?.toString();
    if (requestId == null ||
        requestId.isEmpty ||
        status == null ||
        status.isEmpty) {
      return null;
    }
    return JointOrderStatusPayload(
      requestId: requestId,
      status: status,
      chatRoomId: (map['chatRoomId'] ?? map['chat_room_id'])?.toString(),
      postId: (map['postId'] ?? map['post_id'])?.toString(),
      raw: map,
    );
  }
}

/// 공동 장바구니 상태 알림 페이로드.
class SharedCartStatusPayload {
  const SharedCartStatusPayload({
    required this.eventType,
    required this.roomId,
    this.title,
    this.body,
    required this.raw,
  });

  final String eventType;
  final String roomId;
  final String? title;
  final String? body;
  final Map<String, dynamic> raw;

  static SharedCartStatusPayload? fromMap(Map<String, dynamic> map) {
    final eventType = (map['eventType'] ?? map['event_type'])?.toString();
    final roomId = (map['roomId'] ?? map['room_id'])?.toString();

    if (eventType == null ||
        eventType.isEmpty ||
        roomId == null ||
        roomId.isEmpty) {
      return null;
    }

    return SharedCartStatusPayload(
      eventType: eventType,
      roomId: roomId,
      title: map['title']?.toString(),
      body: map['body']?.toString(),
      raw: map,
    );
  }

  /// eventType에 따른 알림 제목
  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    switch (eventType) {
      case 'order_confirmed':
        return '주문 확정';
      case 'all_paid':
        return '결제 완료';
      case 'all_received':
        return '수령 완료';
      case 'settlement_completed':
        return '정산 완료';
      default:
        return '공동 장바구니 알림';
    }
  }

  /// eventType에 따른 알림 메시지
  String get displayMessage {
    if (body != null && body!.isNotEmpty) return body!;
    switch (eventType) {
      case 'order_confirmed':
        return '주문이 확정되었습니다. 결제를 진행해 주세요.';
      case 'all_paid':
        return '모든 참여자가 결제를 완료했습니다. 배달을 시작해 주세요.';
      case 'all_received':
        return '모든 참여자가 수령을 확인했습니다.';
      case 'settlement_completed':
        return '정산이 완료되었습니다. 포인트가 정산되었습니다.';
      default:
        return '공동 장바구니 상태가 변경되었습니다.';
    }
  }
}
