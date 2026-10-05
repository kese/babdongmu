import 'dart:async';

import 'package:delivery/utils/logging.dart';

import 'api.dart';

class RoomOrderApi {
  static Future<Map<String, dynamic>> finalizeOrder({
    required String roomId,
    required List<String> targetParticipantIds,
    required String cartId,
    required int totalPoint,
    String? memo,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 200));
      logDebug('[RoomOrderApi] Mock order finalized');
      return {'success': true};
    }

    final payload = <String, dynamic>{
      'targetParticipantIds': targetParticipantIds,
      'cartId': cartId,
      'totalPoint': totalPoint,
    };
    if (memo != null && memo.trim().isNotEmpty) {
      payload['memo'] = memo.trim();
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/finalize_order',
      payload,
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> startDelivery({
    required String roomId,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 200));
      logDebug('[RoomOrderApi] Mock delivery started');
      return {'success': true};
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/start_delivery',
      {},
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> confirmReception({
    required String roomId,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 200));
      logDebug('[RoomOrderApi] Mock receipt confirmed');
      return {'success': true};
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/confirm_reception',
      {},
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> reportIssue({
    required String roomId,
    String? memo,
  }) async {
    if (ApiService.isDevelopment) {
      await Future.delayed(const Duration(milliseconds: 200));
      logDebug('[RoomOrderApi] Mock issue reported');
      return {'success': true};
    }

    final payload = <String, dynamic>{};
    if (memo != null && memo.trim().isNotEmpty) {
      payload['memo'] = memo.trim();
    }

    return await ApiService.post(
      'api/v1/chat/rooms/$roomId/report_issue',
      payload,
      requiresAuth: true,
    );
  }
}
