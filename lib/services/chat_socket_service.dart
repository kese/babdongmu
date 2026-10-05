import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../models/chat_message_data.dart';
import 'api.dart';

/// Handles STOMP over WebSocket connections for chat rooms.
class ChatSocketService {
  ChatSocketService._();

  static final ChatSocketService instance = ChatSocketService._();

  final Map<String, StreamController<ChatMessage>> _roomControllers = {};
  final Map<String, void Function()> _activeSubscriptions = {};
  final StreamController<ChatMessage> _globalController =
      StreamController<ChatMessage>.broadcast();

  StompClient? _client;
  Completer<void>? _connectCompleter;
  bool _isConnecting = false;
  String? _currentUserId;

  Stream<ChatMessage> get messageStream => _globalController.stream;

  bool get isConnected => _client?.connected ?? false;

  /// Ensures the STOMP client is connected before performing any operations.
  Future<void> ensureConnected() async {
    final socketUrl = _validatedWebSocketUrl();
    final token = await ApiService.getToken();
    _currentUserId = ApiService.getUserIdFromTokenValue(token);

    if (isConnected) {
      return;
    }

    if (_isConnecting) {
      return _connectCompleter?.future ?? Future.value();
    }

    _isConnecting = true;
    _connectCompleter = Completer<void>();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      headers['accessToken'] = token;
    }

    _client = StompClient(
      config: StompConfig(
        url: socketUrl,
        stompConnectHeaders: headers,
        webSocketConnectHeaders: headers,
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (_) {
          debugPrint('ChatSocketService: STOMP connected');
          _isConnecting = false;
          _connectCompleter?.complete();
          _connectCompleter = null;
          _resubscribeExistingRooms();
        },
        beforeConnect: () async {
          debugPrint('ChatSocketService: attempting STOMP connect...');
          await Future.delayed(const Duration(milliseconds: 200));
        },
        onWebSocketError: (error) {
          debugPrint('ChatSocketService: WebSocket connection error');
          _handleConnectionError(error);
        },
        onStompError: (frame) {
          debugPrint('ChatSocketService: STOMP error frame received');
          _handleConnectionError(Exception('Chat connection failed'));
        },
        onDisconnect: (_) {
          debugPrint('ChatSocketService: disconnected');
          _client = null;
        },
      ),
    );

    _client?.activate();
    return _connectCompleter?.future ?? Future.value();
  }

  String _validatedWebSocketUrl() {
    const configuredUrl = String.fromEnvironment(
      'CHAT_WEBSOCKET_URL',
      defaultValue: 'wss://chat.example.invalid/ws/websocket',
    );
    final uri = Uri.parse(configuredUrl);
    if (uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'CHAT_WEBSOCKET_URL must use WSS without credentials or query data.',
      );
    }
    return configuredUrl;
  }

  /// Subscribes to a room and invokes [onMessage] when new messages arrive.
  Future<StreamSubscription<ChatMessage>> subscribeToRoom({
    required String roomId,
    required void Function(ChatMessage) onMessage,
  }) async {
    await ensureConnected();

    final controller = _roomControllers.putIfAbsent(
      roomId,
      () => StreamController<ChatMessage>.broadcast(
        onListen: () {
          _subscribeRoom(roomId);
        },
        onCancel: () {
          _handleRoomListenerRemoved(roomId);
        },
      ),
    );

    return controller.stream.listen(onMessage);
  }

  /// Unsubscribe explicitly from a room.
  Future<void> unsubscribeFromRoom(String roomId) async {
    _handleRoomListenerRemoved(roomId, force: true);
  }

  /// Sends a chat message via STOMP. Returns true on success.
  Future<bool> sendMessage({
    required String roomId,
    required String messageContent,
    String messageType = 'text',
  }) async {
    try {
      await ensureConnected();
      final client = _client;
      if (client == null || !client.connected) {
        return false;
      }
      client.send(
        destination: '/app/chat.rooms.$roomId/send',
        body: jsonEncode({
          'messageContent': messageContent,
          'messageType': messageType,
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _subscribeRoom(String roomId) {
    if (!isConnected) {
      return;
    }
    if (_activeSubscriptions.containsKey(roomId)) {
      return;
    }
    final client = _client;
    if (client == null) {
      return;
    }

    final unsubscribe = client.subscribe(
      destination: '/topic/chat.rooms.$roomId',
      callback: (frame) => _handleFrame(roomId, frame),
    );

    _activeSubscriptions[roomId] = unsubscribe;
  }

  void _handleFrame(String roomId, StompFrame frame) {
    final body = frame.body;
    if (body == null || body.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        var message = ChatMessage.fromJson(decoded).copyWith(roomId: roomId);
        if (_currentUserId != null && message.senderId.isNotEmpty) {
          final isMine = message.senderId == _currentUserId;
          message = message.copyWith(isMe: isMine);
          debugPrint('ChatSocketService: message ownership resolved');
        }
        final controller = _roomControllers[roomId];
        if (controller != null && !controller.isClosed) {
          debugPrint('ChatSocketService: message received');
          controller.add(message);
        }
        if (!_globalController.isClosed) {
          _globalController.add(message);
        }
      }
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  void _handleRoomListenerRemoved(String roomId, {bool force = false}) {
    final controller = _roomControllers[roomId];
    if (controller == null) {
      return;
    }

    if (!force && controller.hasListener) {
      return;
    }

    _roomControllers.remove(roomId);
    controller.close();

    final unsubscribe = _activeSubscriptions.remove(roomId);
    unsubscribe?.call();
    debugPrint('ChatSocketService: unsubscribed from room');
  }

  void _handleConnectionError(Object error) {
    debugPrint('ChatSocketService: connection error');
    final completer = _connectCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
    _connectCompleter = null;
    _isConnecting = false;
    _client?.deactivate();
    _client = null;
  }

  void _resubscribeExistingRooms() {
    final rooms = _roomControllers.keys.toList(growable: false);
    _activeSubscriptions.clear();
    for (final roomId in rooms) {
      debugPrint('ChatSocketService: restoring a room subscription');
      _subscribeRoom(roomId);
    }
  }

  Future<void> dispose() async {
    for (final unsubscribe in _activeSubscriptions.values) {
      unsubscribe.call();
    }
    _activeSubscriptions.clear();

    for (final controller in _roomControllers.values) {
      await controller.close();
    }
    _roomControllers.clear();
    if (!_globalController.isClosed) {
      await _globalController.close();
    }

    _client?.deactivate();
    _client = null;
  }
}
