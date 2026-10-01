// ignore_for_file: public_member_api_docs
import 'package:flutter/services.dart';

class IosLiveActivityBridge {
  static const _channel = MethodChannel('com.hamza.kratos/focus_session');

  /// Starts or updates a Live Activity on iOS 16.1+ using ActivityKit.
  static Future<void> startLiveActivity({
    required String sessionId,
    required String title,
    String? lifeAreaName,
    required int targetSeconds,
    required DateTime startedAt,
  }) async {
    try {
      await _channel.invokeMethod('startLiveActivity', {
        'sessionId': sessionId,
        'title': title,
        'lifeAreaName': lifeAreaName ?? '',
        'targetSeconds': targetSeconds,
        'startedAtTimestamp': startedAt.millisecondsSinceEpoch,
      });
    } catch (_) {
      // Gracefully ignored on non-iOS or unsupported devices
    }
  }

  /// Ends the active Live Activity.
  static Future<void> endLiveActivity(String sessionId) async {
    try {
      await _channel.invokeMethod('endLiveActivity', {'sessionId': sessionId});
    } catch (_) {}
  }
}
